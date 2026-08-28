const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;

pub const backend: api.Backend = .init(.{
    .canonical_name = "tablegen",
    .display_name = "TableGen",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expected: ?Scope = null,
    after_colon: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.startsWith("//")) {
                try parser.scanLineComment();
            } else if (parser.startsWith("/*")) {
                try parser.scanBlockComment();
            } else if (parser.startsWith("[{")) {
                try parser.scanCodeBlock();
            } else switch (parser.source[parser.index]) {
                '"' => try parser.scanString(),
                '$' => try parser.scanPrefixed(.variable),
                '!' => try parser.scanPrefixed(.builtin),
                '0'...'9' => try parser.scanNumber(),
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                ':' => {
                    try parser.captureByte(.operator);
                    parser.after_colon = true;
                },
                '=', '+', '-', '*', '/', '<', '>', '?' => try parser.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', ';' => try parser.captureByte(.punctuation),
                else => parser.index += validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn startsWith(parser: Parser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn scanLineComment(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len;
        try parser.sink.add(start, parser.index, .comment);
    }

    fn scanBlockComment(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |end| end + 2 else parser.source.len;
        try parser.sink.add(start, parser.index, .comment);
    }

    fn scanCodeBlock(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "}]")) |end| end + 2 else parser.source.len;
        try parser.sink.add(start, parser.index, .embedded);
    }

    fn scanString(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                const escape = parser.index;
                parser.index += 1;
                if (parser.index < parser.source.len) parser.index += validUtf8Length(parser.source[parser.index..]);
                try parser.sink.add(escape, parser.index, .escape);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == '"' or byte == '\n') break;
        }
        try parser.sink.add(start, parser.index, .string);
    }

    fn scanPrefixed(parser: *Parser, scope: Scope) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, parser.index, scope);
    }

    fn scanNumber(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_')) parser.index += 1;
        try parser.sink.add(start, parser.index, .number);
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];

        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            return;
        }
        if (declarationScope(word)) |scope| {
            try parser.sink.add(start, parser.index, .keyword);
            parser.expected = scope;
        } else if (isKeyword(word)) {
            try parser.sink.add(start, parser.index, .keyword);
        } else if (isBuiltinType(word)) {
            try parser.sink.add(start, parser.index, .type);
            try parser.sink.add(start, parser.index, .builtin);
        } else if (isBoolean(word)) {
            try parser.sink.add(start, parser.index, .boolean);
        } else if (parser.after_colon) {
            try parser.sink.add(start, parser.index, .type);
            parser.after_colon = false;
        } else if (nextNonSpace(parser.source, parser.index) == '=') {
            try parser.sink.add(start, parser.index, .property);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanOperator(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and std.mem.indexOfScalar(u8, "=+-*/<>?", parser.source[parser.index]) != null) parser.index += 1;
        try parser.sink.add(start, parser.index, .operator);
    }

    fn captureByte(parser: *Parser, scope: Scope) api.HighlightError!void {
        try parser.sink.add(parser.index, parser.index + 1, scope);
        parser.index += 1;
    }
};

fn declarationScope(word: []const u8) ?Scope {
    if (std.mem.eql(u8, word, "class") or std.mem.eql(u8, word, "multiclass")) return .type;
    if (std.mem.eql(u8, word, "def") or std.mem.eql(u8, word, "defm")) return .constant;
    return null;
}

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "assert", "defset", "defvar", "dump", "else", "field", "foreach", "if", "in", "include", "let", "then" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn isBuiltinType(word: []const u8) bool {
    const words = [_][]const u8{ "bit", "bits", "code", "dag", "int", "list", "string" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn isBoolean(word: []const u8) bool {
    return std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false");
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn nextNonSpace(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
