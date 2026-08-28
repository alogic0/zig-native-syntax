const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
const Scope = @import("../scope.zig").Scope;

const keywords = &.{ "Constraint", "Pattern", "Rewrite", "attr", "erase", "include", "let", "op", "replace", "rewrite", "type", "with" };
const types = &.{ "Attr", "AttrRange", "Op", "OpRange", "Type", "TypeRange", "Value", "ValueRange" };

pub const backend: api.Backend = .init(.{ .canonical_name = "pdll", .display_name = "PDLL", .kind = .parser_backed, .support_level = .verified_structural }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = keywords, .types = types, .classify_identifiers = false });
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    paren_depth: usize = 0,
    expected: ?Scope = null,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r', '\n' => parser.index += 1,
            '/' => {
                if (parser.startsWith("//")) parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len else if (parser.startsWith("/*")) parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |end| end + 2 else parser.source.len else parser.index += 1;
            },
            '"' => parser.skipString(),
            '(' => {
                parser.paren_depth += 1;
                parser.index += 1;
            },
            ')' => {
                parser.paren_depth -|= 1;
                parser.index += 1;
            },
            '$' => try parser.scanDollarMember(),
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn startsWith(parser: StructureParser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn skipString(parser: *StructureParser) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') parser.index += @min(@as(usize, 2), parser.source.len - parser.index) else {
                const byte = parser.source[parser.index];
                parser.index += 1;
                if (byte == '"' or byte == '\n') break;
            }
        }
    }

    fn scanDollarMember(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, parser.index, .property);
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (isIdentifierContinue(parser.source[parser.index]) or parser.source[parser.index] == '.')) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
        } else if (std.mem.eql(u8, word, "Pattern") or std.mem.eql(u8, word, "Rewrite") or std.mem.eql(u8, word, "Constraint")) {
            parser.expected = .function;
        } else if (std.mem.eql(u8, word, "let")) {
            parser.expected = .variable;
        } else if (parser.paren_depth > 0 and nextNonSpace(parser.source, parser.index) == ':') {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (previousDot(parser.source, start)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (!contains(keywords, word) and !contains(types, word)) {
            try parser.sink.add(start, parser.index, .variable);
        }
    }
};

fn contains(words: []const []const u8, word: []const u8) bool {
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn previousDot(source: []const u8, before: usize) bool {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return cursor > 0 and source[cursor - 1] == '.';
}

fn nextNonSpace(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
