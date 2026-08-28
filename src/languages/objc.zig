const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const Span = @import("../capture.zig").Span;
const g = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "objc",
    .display_name = "Objective-C",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"//"},
        .block_comments = &.{.{ .open = "/*", .close = "*/" }},
        .keywords = &.{ "interface", "implementation", "protocol", "property", "synthesize", "dynamic", "selector", "encode", "end", "class", "public", "private", "protected", "package", "try", "catch", "finally", "throw", "synchronized", "autoreleasepool", "import", "return", "if", "else", "for", "while" },
        .types = &.{ "BOOL", "Class", "IMP", "SEL", "id", "instancetype", "int", "void" },
        .preprocessor = true,
        .identifier_dash = false,
        .at_scope = null,
    });
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    line_start: usize = 0,
    expected: ?Scope = null,
    square_depth: usize = 0,
    message_word_count: usize = 0,
    property_candidate: ?Span = null,
    in_property: bool = false,
    pending_block_parameters: bool = false,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.atPreprocessorStart()) {
                parser.skipLine();
            } else if (parser.startsWith("//")) {
                parser.skipLine();
            } else if (parser.startsWith("/*")) {
                parser.skipBlock();
            } else switch (parser.source[parser.index]) {
                '\n' => {
                    parser.index += 1;
                    parser.line_start = parser.index;
                },
                '\'', '"' => parser.skipString(parser.source[parser.index]),
                '@' => try parser.scanAtConstruct(),
                '^' => try parser.scanBlockName(),
                '(' => {
                    if (parser.pending_block_parameters) {
                        try parser.scanBlockParameters();
                        parser.pending_block_parameters = false;
                    } else {
                        parser.index += 1;
                    }
                },
                '[' => {
                    parser.square_depth += 1;
                    parser.message_word_count = 0;
                    parser.index += 1;
                },
                ']' => {
                    parser.square_depth -|= 1;
                    parser.message_word_count = 0;
                    parser.index += 1;
                },
                '-', '+' => {
                    if (parser.onlyIndentBefore()) {
                        try parser.scanMethod();
                    } else {
                        parser.index += 1;
                    }
                },
                ';' => {
                    if (parser.in_property) if (parser.property_candidate) |span| try parser.sink.add(span.start, span.end, .property);
                    parser.in_property = false;
                    parser.property_candidate = null;
                    parser.index += 1;
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanAtConstruct(parser: *StructureParser) api.HighlightError!void {
        if (parser.index + 1 >= parser.source.len) {
            parser.index += 1;
            return;
        }
        if (parser.source[parser.index + 1] == '"') {
            try parser.scanObjcString();
        } else if (parser.source[parser.index + 1] == '[' or parser.source[parser.index + 1] == '{' or
            parser.source[parser.index + 1] == '(' or std.ascii.isDigit(parser.source[parser.index + 1]))
        {
            try parser.sink.add(parser.index, parser.index + 1, .special);
            parser.index += 1;
        } else {
            try parser.scanDirective();
        }
    }

    fn scanDirective(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const directive = parser.source[start + 1 .. parser.index];
        if (directive.len == 0) return;
        if (wordIs(directive, &.{ "YES", "NO" })) {
            try parser.sink.add(start, parser.index, .boolean);
            return;
        }
        if (!isDirective(directive)) return;
        try parser.sink.add(start, parser.index, .keyword);
        if (wordIs(directive, &.{ "interface", "implementation", "protocol" })) {
            parser.expected = .type;
        } else if (std.mem.eql(u8, directive, "class")) {
            parser.expected = .type;
        } else if (std.mem.eql(u8, directive, "property")) {
            parser.in_property = true;
            parser.property_candidate = null;
        } else if (std.mem.eql(u8, directive, "selector")) {
            try parser.scanSelector();
        }
    }

    fn scanSelector(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len and std.ascii.isWhitespace(parser.source[parser.index])) parser.index += 1;
        if (parser.index >= parser.source.len or parser.source[parser.index] != '(') return;
        parser.index += 1;
        while (parser.index < parser.source.len and parser.source[parser.index] != ')') {
            if (isIdentifierStart(parser.source[parser.index])) {
                const start = parser.index;
                parser.index += 1;
                while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
                try parser.sink.add(start, parser.index, .function);
            } else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        if (parser.index < parser.source.len) parser.index += 1;
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
        } else if (parser.in_property and !isQualifier(word) and !isBuiltinType(word)) {
            parser.property_candidate = .{ .start = start, .end = parser.index };
            if (std.ascii.isUpper(word[0])) try parser.sink.add(start, parser.index, .type);
        } else if (parser.square_depth > 0) {
            parser.message_word_count += 1;
            if (scanner.nextNonSpace(parser.source, parser.index) == ':' or parser.message_word_count == 2) try parser.sink.add(start, parser.index, .function);
        } else if (std.ascii.isUpper(word[0]) and !isBuiltinType(word)) {
            try parser.sink.add(start, parser.index, .type);
        }
    }

    fn scanMethod(parser: *StructureParser) api.HighlightError!void {
        parser.index += 1;
        var expect_parameter = false;
        var method_name_seen = false;
        while (parser.index < parser.source.len and parser.source[parser.index] != ';' and parser.source[parser.index] != '{') {
            switch (parser.source[parser.index]) {
                '\'', '"' => parser.skipString(parser.source[parser.index]),
                '(' => try parser.scanMethodType(),
                '\n' => {
                    parser.index += 1;
                    parser.line_start = parser.index;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    const start = parser.index;
                    parser.index += 1;
                    while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
                    if (!method_name_seen or scanner.nextNonSpace(parser.source, parser.index) == ':') {
                        try parser.sink.add(start, parser.index, .function);
                        method_name_seen = true;
                        if (scanner.nextNonSpace(parser.source, parser.index) == ':') expect_parameter = true;
                    } else if (expect_parameter) {
                        try parser.sink.add(start, parser.index, .parameter);
                        expect_parameter = false;
                    }
                },
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanMethodType(parser: *StructureParser) api.HighlightError!void {
        parser.index += 1;
        var depth: usize = 1;
        while (parser.index < parser.source.len and depth > 0) {
            if (parser.source[parser.index] == '(') {
                depth += 1;
                parser.index += 1;
                continue;
            }
            if (parser.source[parser.index] == ')') {
                depth -= 1;
                parser.index += 1;
                continue;
            }
            if (isIdentifierStart(parser.source[parser.index])) {
                const start = parser.index;
                parser.index += 1;
                while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
                const word = parser.source[start..parser.index];
                try parser.sink.add(start, parser.index, if (isBuiltinType(word) or std.ascii.isUpper(word[0])) .type else .parameter);
            } else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
    }

    fn scanBlockName(parser: *StructureParser) api.HighlightError!void {
        const operator = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and std.ascii.isWhitespace(parser.source[parser.index])) parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '(') {
            parser.pending_block_parameters = true;
            return;
        }
        if (parser.index < parser.source.len and isIdentifierStart(parser.source[parser.index])) {
            const start = parser.index;
            parser.index += 1;
            while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
            if (scanner.nextNonSpace(parser.source, parser.index) == ')') {
                try parser.sink.add(start, parser.index, .variable);
                parser.pending_block_parameters = true;
                return;
            }
        }
        parser.index = operator + 1;
    }

    fn scanBlockParameters(parser: *StructureParser) api.HighlightError!void {
        parser.index += 1;
        var depth: usize = 1;
        while (parser.index < parser.source.len and depth > 0) switch (parser.source[parser.index]) {
            '(' => {
                depth += 1;
                parser.index += 1;
            },
            ')' => {
                depth -= 1;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => {
                const start = parser.index;
                parser.index += 1;
                while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
                const word = parser.source[start..parser.index];
                try parser.sink.add(start, parser.index, if (isBuiltinType(word) or std.ascii.isUpper(word[0])) .type else .parameter);
            },
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn atPreprocessorStart(parser: StructureParser) bool {
        return parser.source[parser.index] == '#' and parser.onlyIndentBefore();
    }

    fn onlyIndentBefore(parser: StructureParser) bool {
        for (parser.source[parser.line_start..parser.index]) |byte| if (byte != ' ' and byte != '\t') return false;
        return true;
    }

    fn startsWith(parser: StructureParser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn skipLine(parser: *StructureParser) void {
        parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
    }

    fn skipBlock(parser: *StructureParser) void {
        parser.index = scanner.blockCommentEnd(parser.source, parser.index, parser.source.len);
    }

    fn scanObjcString(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        parser.skipString('"');
        try parser.sink.add(start, parser.index, .string);
    }

    fn skipString(parser: *StructureParser, quote: u8) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == quote or byte == '\n') break;
        }
    }
};

fn wordIs(word: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

fn isQualifier(word: []const u8) bool {
    return wordIs(word, &.{ "atomic", "nonatomic", "assign", "copy", "getter", "nullable", "readonly", "readwrite", "retain", "setter", "strong", "weak" });
}

fn isBuiltinType(word: []const u8) bool {
    return wordIs(word, &.{ "BOOL", "Class", "IMP", "SEL", "id", "instancetype", "int", "void" });
}

fn isDirective(word: []const u8) bool {
    return wordIs(word, &.{ "autoreleasepool", "available", "catch", "class", "dynamic", "encode", "end", "finally", "implementation", "interface", "optional", "package", "private", "property", "protected", "protocol", "public", "required", "selector", "synchronized", "synthesize", "throw", "try" });
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
