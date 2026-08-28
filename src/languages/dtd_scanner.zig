const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var lexer: Lexer = .{ .source = source, .sink = sink };
    try lexer.run();
}

const Declaration = enum { none, element, attlist, entity, notation, doctype };
const AttributePhase = enum { element, attribute, attr_type, default };

const Lexer = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    declaration: Declaration = .none,
    declaration_name_seen: bool = false,
    attribute_phase: AttributePhase = .element,
    attribute_enumeration: bool = false,

    fn run(lexer: *Lexer) api.HighlightError!void {
        while (lexer.index < lexer.source.len) {
            if (std.mem.startsWith(u8, lexer.source[lexer.index..], "<!--")) {
                try lexer.scanDelimited("-->", .comment);
            } else if (std.mem.startsWith(u8, lexer.source[lexer.index..], "<?")) {
                try lexer.scanDelimited("?>", .special);
            } else if (std.mem.startsWith(u8, lexer.source[lexer.index..], "<![")) {
                try lexer.scanConditionalSection();
            } else if (std.mem.startsWith(u8, lexer.source[lexer.index..], "<!")) {
                try lexer.scanDeclarationStart();
            } else switch (lexer.source[lexer.index]) {
                '\'', '"' => try lexer.scanString(),
                '&' => try lexer.scanReference('&'),
                '%' => try lexer.scanReference('%'),
                '#' => try lexer.scanHashWord(),
                '0'...'9' => try lexer.scanNumber(),
                '<', '(', '[', '|', ',', '?', '*', '+' => try lexer.captureByte(.punctuation),
                '>' => {
                    try lexer.captureByte(.punctuation);
                    lexer.resetDeclaration();
                },
                ')', ']' => {
                    try lexer.captureByte(.punctuation);
                    if (lexer.declaration == .attlist and lexer.attribute_enumeration and lexer.source[lexer.index - 1] == ')') {
                        lexer.attribute_enumeration = false;
                        lexer.attribute_phase = .default;
                    }
                },
                '=' => try lexer.captureByte(.operator),
                else => if (isNameStart(lexer.source[lexer.index])) {
                    try lexer.scanName();
                } else {
                    lexer.index += scanner.validUtf8Length(lexer.source[lexer.index..]);
                },
            }
        }
    }

    fn scanDeclarationStart(lexer: *Lexer) api.HighlightError!void {
        try lexer.sink.add(lexer.index, lexer.index + 2, .punctuation);
        lexer.index += 2;
        while (lexer.index < lexer.source.len and std.ascii.isWhitespace(lexer.source[lexer.index])) lexer.index += 1;
        const start = lexer.index;
        lexer.index = nameEnd(lexer.source, lexer.index);
        if (lexer.index == start) return;
        const word = lexer.source[start..lexer.index];
        lexer.declaration = declarationFor(word);
        lexer.declaration_name_seen = false;
        lexer.attribute_phase = .element;
        lexer.attribute_enumeration = false;
        try lexer.sink.add(start, lexer.index, .keyword);
    }

    fn scanName(lexer: *Lexer) api.HighlightError!void {
        const start = lexer.index;
        lexer.index = nameEnd(lexer.source, lexer.index);
        const word = lexer.source[start..lexer.index];
        if (isKeyword(word)) {
            try lexer.sink.add(start, lexer.index, if (isAttributeType(word)) .type else .keyword);
            if (lexer.declaration == .attlist and lexer.attribute_phase == .attr_type and !std.mem.eql(u8, word, "NOTATION")) {
                lexer.attribute_phase = .default;
            }
            return;
        }

        switch (lexer.declaration) {
            .element => {
                try lexer.sink.add(start, lexer.index, .tag);
                lexer.declaration_name_seen = true;
            },
            .attlist => switch (lexer.attribute_phase) {
                .element => {
                    try lexer.sink.add(start, lexer.index, .tag);
                    lexer.attribute_phase = .attribute;
                },
                .attribute => {
                    try lexer.sink.add(start, lexer.index, .attribute);
                    lexer.attribute_phase = .attr_type;
                },
                .attr_type => if (lexer.attribute_enumeration) {
                    try lexer.sink.add(start, lexer.index, .constant);
                } else {
                    try lexer.sink.add(start, lexer.index, .type);
                    lexer.attribute_phase = .default;
                },
                .default => {
                    try lexer.sink.add(start, lexer.index, .constant);
                    lexer.attribute_phase = .attribute;
                },
            },
            .entity => {
                try lexer.sink.add(start, lexer.index, .constant);
                lexer.declaration_name_seen = true;
            },
            .notation => {
                try lexer.sink.add(start, lexer.index, if (lexer.declaration_name_seen) .constant else .type);
                lexer.declaration_name_seen = true;
            },
            .doctype => {
                try lexer.sink.add(start, lexer.index, if (lexer.declaration_name_seen) .constant else .tag);
                lexer.declaration_name_seen = true;
            },
            .none => {},
        }
    }

    fn scanString(lexer: *Lexer) api.HighlightError!void {
        const start = lexer.index;
        const quote = lexer.source[lexer.index];
        lexer.index += 1;
        while (lexer.index < lexer.source.len and lexer.source[lexer.index] != quote) {
            if (lexer.source[lexer.index] == '&') {
                try lexer.scanReference('&');
            } else {
                lexer.index += scanner.validUtf8Length(lexer.source[lexer.index..]);
            }
        }
        if (lexer.index < lexer.source.len) lexer.index += 1;
        try lexer.sink.add(start, lexer.index, .string);
        if (lexer.declaration == .attlist and lexer.attribute_phase == .default) lexer.attribute_phase = .attribute;
    }

    fn scanReference(lexer: *Lexer, rune: u8) api.HighlightError!void {
        const start = lexer.index;
        var end = start + 1;
        const character_reference = rune == '&' and end < lexer.source.len and lexer.source[end] == '#';
        if (character_reference) {
            end += 1;
            if (end < lexer.source.len and lexer.source[end] == 'x') end += 1;
            const digits_start = end;
            while (end < lexer.source.len and std.ascii.isHex(lexer.source[end])) end += 1;
            if (end == digits_start) {
                try lexer.captureByte(.punctuation);
                return;
            }
            if (end < lexer.source.len and lexer.source[end] == ';') end += 1;
            lexer.index = end;
            try lexer.sink.add(start, end, .escape);
            return;
        }
        if (end >= lexer.source.len or !isNameStart(lexer.source[end])) {
            try lexer.captureByte(.punctuation);
            return;
        }
        end = nameEnd(lexer.source, end);
        if (end < lexer.source.len and lexer.source[end] == ';') end += 1;
        lexer.index = end;
        try lexer.sink.add(start, end, .escape);
        try lexer.sink.add(start, end, .constant);
    }

    fn scanHashWord(lexer: *Lexer) api.HighlightError!void {
        const start = lexer.index;
        lexer.index += 1;
        if (lexer.index >= lexer.source.len or !isNameStart(lexer.source[lexer.index])) {
            try lexer.sink.add(start, lexer.index, .punctuation);
            return;
        }
        lexer.index = nameEnd(lexer.source, lexer.index);
        const word = lexer.source[start..lexer.index];
        try lexer.sink.add(start, lexer.index, .keyword);
        if (lexer.declaration == .attlist and lexer.attribute_phase == .default and !std.mem.eql(u8, word, "#FIXED")) {
            lexer.attribute_phase = .attribute;
        }
    }

    fn scanNumber(lexer: *Lexer) api.HighlightError!void {
        const start = lexer.index;
        while (lexer.index < lexer.source.len and std.ascii.isDigit(lexer.source[lexer.index])) lexer.index += 1;
        try lexer.sink.add(start, lexer.index, .number);
    }

    fn scanConditionalSection(lexer: *Lexer) api.HighlightError!void {
        const start = lexer.index;
        var keyword_start = start + 3;
        while (keyword_start < lexer.source.len and std.ascii.isWhitespace(lexer.source[keyword_start])) keyword_start += 1;
        const keyword_end = nameEnd(lexer.source, keyword_start);
        if (keyword_end > keyword_start and std.mem.eql(u8, lexer.source[keyword_start..keyword_end], "IGNORE")) {
            const end = ignoredSectionEnd(lexer.source, keyword_end);
            try lexer.sink.add(start, end, .comment);
            try lexer.sink.add(keyword_start, keyword_end, .keyword);
            lexer.index = end;
            return;
        }
        try lexer.sink.add(start, start + 3, .punctuation);
        lexer.index = start + 3;
    }

    fn scanDelimited(lexer: *Lexer, close: []const u8, scope: @import("../scope.zig").Scope) api.HighlightError!void {
        const start = lexer.index;
        const close_at = std.mem.indexOfPos(u8, lexer.source, lexer.index + 2, close);
        lexer.index = if (close_at) |at| at + close.len else lexer.source.len;
        try lexer.sink.add(start, lexer.index, scope);
    }

    fn captureByte(lexer: *Lexer, scope: @import("../scope.zig").Scope) api.HighlightError!void {
        try lexer.sink.add(lexer.index, lexer.index + 1, scope);
        if (lexer.declaration == .attlist and lexer.source[lexer.index] == '(' and lexer.attribute_phase == .attr_type) {
            lexer.attribute_enumeration = true;
        }
        lexer.index += 1;
    }

    fn resetDeclaration(lexer: *Lexer) void {
        lexer.declaration = .none;
        lexer.declaration_name_seen = false;
        lexer.attribute_phase = .element;
        lexer.attribute_enumeration = false;
    }
};

fn declarationFor(word: []const u8) Declaration {
    if (std.mem.eql(u8, word, "ELEMENT")) return .element;
    if (std.mem.eql(u8, word, "ATTLIST")) return .attlist;
    if (std.mem.eql(u8, word, "ENTITY")) return .entity;
    if (std.mem.eql(u8, word, "NOTATION")) return .notation;
    if (std.mem.eql(u8, word, "DOCTYPE")) return .doctype;
    return .none;
}

fn isKeyword(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "ANY", "CDATA", "EMPTY", "ENTITIES", "ENTITY", "ID", "IDREF", "IDREFS", "INCLUDE", "NDATA", "NMTOKEN", "NMTOKENS", "NOTATION", "PUBLIC", "SYSTEM" });
}

fn isAttributeType(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "CDATA", "ENTITIES", "ENTITY", "ID", "IDREF", "IDREFS", "NMTOKEN", "NMTOKENS", "NOTATION" });
}

fn isNameStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_' or byte == ':' or byte >= 0x80;
}

fn isNameContinue(byte: u8) bool {
    return isNameStart(byte) or std.ascii.isDigit(byte) or byte == '-' or byte == '.';
}

fn nameEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and isNameContinue(source[index])) index += scanner.validUtf8Length(source[index..]);
    return index;
}

fn ignoredSectionEnd(source: []const u8, after_keyword: usize) usize {
    var index = after_keyword;
    var depth: usize = 1;
    while (index < source.len) {
        if (std.mem.startsWith(u8, source[index..], "<![")) {
            depth += 1;
            index += 3;
        } else if (std.mem.startsWith(u8, source[index..], "]]>")) {
            depth -= 1;
            index += 3;
            if (depth == 0) return index;
        } else {
            index += scanner.validUtf8Length(source[index..]);
        }
    }
    return source.len;
}

test "DTD ignored sections recover through nesting" {
    const nested = "<![IGNORE[ one <![ two ]]> three ]]>";
    const broken = "<![IGNORE[x";
    try std.testing.expectEqual(nested.len, ignoredSectionEnd(nested, 9));
    try std.testing.expectEqual(broken.len, ignoredSectionEnd(broken, 9));
}
