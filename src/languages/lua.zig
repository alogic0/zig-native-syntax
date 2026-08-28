const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;

pub const backend: api.Backend = .init(.{
    .canonical_name = "lua",
    .display_name = "Lua",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

/// A tolerant Lua event parser. It tracks declarations, function signatures,
/// member access, calls, labels, and Lua's balanced long-bracket literals while
/// continuing after incomplete input.
const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    expect_parameter: bool = false,
    expect_function_name: bool = false,
    expect_local_name: bool = false,
    expect_label: bool = false,
    member_access: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "--")) {
                try parser.scanComment();
                continue;
            }
            if (longBracket(parser.source, parser.index)) |bracket| {
                try parser.scanLongLiteral(bracket, .string);
                parser.member_access = false;
                continue;
            }

            switch (parser.source[parser.index]) {
                '\n' => {
                    parser.index += 1;
                    parser.expect_local_name = false;
                    parser.expect_label = false;
                    parser.member_access = false;
                },
                ' ', '\t', '\r' => parser.index += 1,
                '\'', '"' => try parser.scanQuotedString(),
                '0'...'9' => try parser.scanNumber(),
                'a'...'z', 'A'...'Z', '_' => try parser.scanIdentifier(),
                '+', '-', '*', '/', '%', '^', '#', '=', '~', '<', '>', '&', '|' => try parser.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', '.', ':', ';' => try parser.scanPunctuation(),
                else => parser.advanceUnknown(),
            }
        }
    }

    fn scanComment(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 2;
        if (longBracket(parser.source, parser.index)) |bracket| {
            parser.index = longLiteralEnd(parser.source, parser.index, bracket);
        } else {
            parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len;
        }
        try parser.sink.add(start, parser.index, .comment);
        parser.member_access = false;
    }

    fn scanLongLiteral(parser: *Parser, bracket: LongBracket, scope: Scope) api.HighlightError!void {
        const start = parser.index;
        parser.index = longLiteralEnd(parser.source, start, bracket);
        try parser.sink.add(start, parser.index, scope);
    }

    fn scanQuotedString(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        const quote = parser.source[parser.index];
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                const escape_start = parser.index;
                parser.index = escapeEnd(parser.source, parser.index);
                try parser.sink.add(escape_start, parser.index, .escape);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == quote or byte == '\n') break;
        }
        try parser.sink.add(start, parser.index, .string);
        parser.member_access = false;
    }

    fn scanNumber(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len) {
            const byte = parser.source[parser.index];
            if (std.ascii.isAlphanumeric(byte) or byte == '.' or byte == '_') {
                parser.index += 1;
            } else if ((byte == '+' or byte == '-') and parser.index > start and
                std.mem.indexOfScalar(u8, "eEpP", parser.source[parser.index - 1]) != null)
            {
                parser.index += 1;
            } else break;
        }
        try parser.sink.add(start, parser.index, .number);
        parser.member_access = false;
    }

    fn scanIdentifier(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        const next = nextNonSpaceByte(parser.source, parser.index);

        if (isKeyword(word)) {
            try parser.sink.add(start, parser.index, .keyword);
            if (std.mem.eql(u8, word, "function")) {
                parser.expect_function_name = next != '(';
                if (next == '(') parser.parameter_depth = parser.paren_depth + 1;
            } else if (std.mem.eql(u8, word, "local")) {
                parser.expect_local_name = true;
            } else if (std.mem.eql(u8, word, "goto")) {
                parser.expect_label = true;
            }
        } else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false")) {
            try parser.sink.add(start, parser.index, .boolean);
        } else if (std.mem.eql(u8, word, "nil")) {
            try parser.sink.add(start, parser.index, .constant);
        } else if (parser.expect_label) {
            try parser.sink.add(start, parser.index, .label);
            parser.expect_label = false;
        } else if (parser.expect_function_name) {
            const final_segment = next != '.' and next != ':';
            try parser.sink.add(start, parser.index, if (final_segment) .function else .namespace);
            if (final_segment) {
                parser.expect_function_name = false;
                if (next == '(') parser.parameter_depth = parser.paren_depth + 1;
            }
        } else if (parser.parameter_depth == parser.paren_depth and parser.expect_parameter) {
            try parser.sink.add(start, parser.index, .parameter);
            parser.expect_parameter = false;
        } else if (parser.expect_local_name) {
            try parser.sink.add(start, parser.index, .variable);
            parser.expect_local_name = next == ',';
        } else if (parser.member_access) {
            try parser.sink.add(start, parser.index, .property);
            if (next == '(') try parser.sink.add(start, parser.index, .function);
        } else if (isBuiltin(word)) {
            try parser.sink.add(start, parser.index, .builtin);
        } else if (next == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
        parser.member_access = false;
    }

    fn scanOperator(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and
            std.mem.indexOfScalar(u8, "+-*/%^#=~<>&|", parser.source[parser.index]) != null)
        {
            parser.index += 1;
        }
        try parser.sink.add(start, parser.index, .operator);
        parser.member_access = false;
    }

    fn scanPunctuation(parser: *Parser) api.HighlightError!void {
        const byte = parser.source[parser.index];
        if (byte == ':' and parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == ':') {
            try parser.sink.add(parser.index, parser.index + 2, .punctuation);
            parser.index += 2;
            parser.expect_label = true;
            parser.member_access = false;
            return;
        }

        switch (byte) {
            '(' => {
                parser.paren_depth += 1;
                if (parser.parameter_depth == parser.paren_depth) parser.expect_parameter = true;
            },
            ')' => {
                if (parser.parameter_depth == parser.paren_depth) {
                    parser.parameter_depth = null;
                    parser.expect_parameter = false;
                }
                parser.paren_depth -|= 1;
            },
            ',' => {
                if (parser.parameter_depth == parser.paren_depth) parser.expect_parameter = true;
            },
            '.', ':' => parser.member_access = true,
            else => parser.member_access = false,
        }
        try parser.sink.add(parser.index, parser.index + 1, .punctuation);
        parser.index += 1;

        if (byte == '(' and parser.parameter_depth == null and !parser.expect_function_name and
            previousWordIs(parser.source, parser.index - 1, "function"))
        {
            parser.parameter_depth = parser.paren_depth;
            parser.expect_parameter = true;
        }
    }

    fn advanceUnknown(parser: *Parser) void {
        parser.index += validUtf8SequenceLength(parser.source[parser.index..]) orelse 1;
        parser.member_access = false;
    }
};

const LongBracket = struct { equals: usize, open_len: usize };

fn longBracket(source: []const u8, start: usize) ?LongBracket {
    if (start >= source.len or source[start] != '[') return null;
    var cursor = start + 1;
    while (cursor < source.len and source[cursor] == '=') cursor += 1;
    if (cursor >= source.len or source[cursor] != '[') return null;
    return .{ .equals = cursor - start - 1, .open_len = cursor - start + 1 };
}

fn longLiteralEnd(source: []const u8, start: usize, bracket: LongBracket) usize {
    var cursor = start + bracket.open_len;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] != ']') continue;
        var close = cursor + 1;
        var equals: usize = 0;
        while (close < source.len and source[close] == '=') : (close += 1) equals += 1;
        if (equals == bracket.equals and close < source.len and source[close] == ']') return close + 1;
    }
    return source.len;
}

fn escapeEnd(source: []const u8, start: usize) usize {
    var cursor = start + 1;
    if (cursor >= source.len) return source.len;
    if (source[cursor] == 'z') {
        cursor += 1;
        while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
        return cursor;
    }
    if (source[cursor] == 'x') {
        cursor += 1;
        var digits: usize = 0;
        while (cursor < source.len and digits < 2 and std.ascii.isHex(source[cursor])) : ({
            cursor += 1;
            digits += 1;
        }) {}
        return cursor;
    }
    if (source[cursor] == 'u' and cursor + 1 < source.len and source[cursor + 1] == '{') {
        cursor += 2;
        while (cursor < source.len and source[cursor] != '}' and source[cursor] != '\n') cursor += 1;
        if (cursor < source.len and source[cursor] == '}') cursor += 1;
        return cursor;
    }
    if (std.ascii.isDigit(source[cursor])) {
        var digits: usize = 0;
        while (cursor < source.len and digits < 3 and std.ascii.isDigit(source[cursor])) : ({
            cursor += 1;
            digits += 1;
        }) {}
        return cursor;
    }
    return cursor + (validUtf8SequenceLength(source[cursor..]) orelse 1);
}

fn previousWordIs(source: []const u8, before: usize, expected: []const u8) bool {
    var end = before;
    while (end > 0 and std.ascii.isWhitespace(source[end - 1])) end -= 1;
    var start = end;
    while (start > 0 and isIdentifierContinue(source[start - 1])) start -= 1;
    return std.mem.eql(u8, source[start..end], expected);
}

fn nextNonSpaceByte(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and (source[cursor] == ' ' or source[cursor] == '\t' or source[cursor] == '\r')) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{
        "and",   "break", "do", "else",   "elseif", "end",  "for",   "function", "goto", "if", "in",
        "local", "not",   "or", "repeat", "return", "then", "until", "while",
    };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

fn isBuiltin(word: []const u8) bool {
    const words = [_][]const u8{
        "assert",  "collectgarbage", "dofile",       "error",    "getmetatable", "ipairs", "load",   "loadfile",
        "next",    "pairs",          "pcall",        "print",    "rawequal",     "rawget", "rawlen", "rawset",
        "require", "select",         "setmetatable", "tonumber", "tostring",     "type",   "warn",   "xpcall",
        "_G",      "_VERSION",
    };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
