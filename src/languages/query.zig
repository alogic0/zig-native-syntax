const std = @import("std");
const api = @import("../backend.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "query",
    .display_name = "Tree-sitter Query",
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
    after_open: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r', '\n' => parser.index += 1,
            ';' => try parser.scanComment(),
            '"' => try parser.scanString(),
            '(', '[', ')', ']' => try parser.scanDelimiter(),
            '@' => try parser.scanPrefixed(.attribute),
            '#' => try parser.scanPrefixed(.function),
            '*', '+', '?' => {
                try parser.sink.add(parser.index, parser.index + 1, .operator);
                parser.index += 1;
                parser.after_open = false;
            },
            '.', ':' => {
                try parser.sink.add(parser.index, parser.index + 1, if (parser.source[parser.index] == '.') .special else .punctuation);
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_', '-' => try parser.scanName(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanComment(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = std.mem.indexOfScalarPos(u8, parser.source, start, '\n') orelse parser.source.len;
        try parser.sink.add(start, parser.index, .comment);
    }

    fn scanString(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                const escape_start = parser.index;
                parser.index += 1;
                if (parser.index < parser.source.len) parser.index += validUtf8Length(parser.source[parser.index..]);
                try parser.sink.add(escape_start, parser.index, .escape);
            } else {
                const byte = parser.source[parser.index];
                parser.index += 1;
                if (byte == '"' or byte == '\n') break;
            }
        }
        try parser.sink.add(start, parser.index, .string);
        parser.after_open = false;
    }

    fn scanDelimiter(parser: *Parser) api.HighlightError!void {
        const byte = parser.source[parser.index];
        try parser.sink.add(parser.index, parser.index + 1, .punctuation);
        parser.index += 1;
        parser.after_open = byte == '(' or byte == '[';
    }

    fn scanPrefixed(parser: *Parser, scope: @import("../scope.zig").Scope) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isNameByte(parser.source[parser.index])) parser.index += 1;
        if (scope == .function and parser.index < parser.source.len and parser.source[parser.index] == '?') parser.index += 1;
        try parser.sink.add(start, parser.index, scope);
        parser.after_open = false;
    }

    fn scanName(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isNameByte(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        const next = nextNonSpace(parser.source, parser.index);
        if (std.mem.eql(u8, word, "ERROR") or std.mem.eql(u8, word, "MISSING")) {
            try parser.sink.add(start, parser.index, .constant);
        } else if (next == ':') {
            try parser.sink.add(start, parser.index, .property);
        } else if (parser.after_open) {
            try parser.sink.add(start, parser.index, .type);
        }
        parser.after_open = false;
    }
};

fn isNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-' or byte == '.';
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
