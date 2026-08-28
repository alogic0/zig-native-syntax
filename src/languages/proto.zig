const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "proto",
    .display_name = "Protocol Buffers",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "syntax", "package", "import", "option", "message", "enum", "service", "rpc", "returns", "repeated", "optional", "required", "oneof", "map", "reserved", "extend", "extensions", "to", "max", "stream" }, .types = &.{ "bool", "bytes", "double", "fixed32", "fixed64", "float", "int32", "int64", "sfixed32", "sfixed64", "sint32", "sint64", "string", "uint32", "uint64" } });
    var parser: StructureParser = .{ .source = s, .sink = k };
    try parser.run();
}

/// Contextual declaration pass over the source-preserving lexical scanner.
const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    brace_depth: usize = 0,
    enum_depth: ?usize = null,
    expected: ?@import("../scope.zig").Scope = null,
    expect_field_name: bool = false,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r', '\n' => parser.index += 1,
            '/' => {
                if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '/') {
                    parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len;
                } else if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '*') {
                    parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |end| end + 2 else parser.source.len;
                } else parser.index += 1;
            },
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            '{' => {
                parser.brace_depth += 1;
                parser.index += 1;
            },
            '}' => {
                if (parser.enum_depth == parser.brace_depth) parser.enum_depth = null;
                parser.brace_depth -|= 1;
                parser.index += 1;
                parser.expect_field_name = false;
            },
            ';' => {
                parser.index += 1;
                parser.expected = null;
                parser.expect_field_name = false;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanIdentifier(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
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

    fn scanIdentifier(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_')) parser.index += 1;
        const word = parser.source[start..parser.index];
        const next = nextNonSpace(parser.source, parser.index);

        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            if (scope == .type and previousWord(parser.source, start, "enum")) parser.enum_depth = parser.brace_depth + 1;
            if (scope == .type and next != '{') parser.expect_field_name = true;
            return;
        }
        if (std.mem.eql(u8, word, "message") or std.mem.eql(u8, word, "enum") or
            std.mem.eql(u8, word, "service") or std.mem.eql(u8, word, "oneof") or
            std.mem.eql(u8, word, "extend"))
        {
            parser.expected = .type;
        } else if (std.mem.eql(u8, word, "rpc")) {
            parser.expected = .function;
        } else if (std.mem.eql(u8, word, "package")) {
            parser.expected = .namespace;
        } else if (std.mem.eql(u8, word, "option")) {
            parser.expected = .property;
        } else if (isFieldModifier(word)) {
            parser.expect_field_name = false;
        } else if (isScalarType(word)) {
            parser.expect_field_name = true;
        } else if (parser.expect_field_name) {
            try parser.sink.add(start, parser.index, .property);
            parser.expect_field_name = false;
        } else if (parser.enum_depth != null and next == '=') {
            try parser.sink.add(start, parser.index, .constant);
        } else if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .type);
            if (parser.brace_depth > 0 and next != ')' and next != '(') parser.expect_field_name = true;
        } else if (next == '(') {
            try parser.sink.add(start, parser.index, .function);
        }
    }
};

fn nextNonSpace(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

fn previousWord(source: []const u8, before: usize, expected: []const u8) bool {
    var end = before;
    while (end > 0 and std.ascii.isWhitespace(source[end - 1])) end -= 1;
    var start = end;
    while (start > 0 and (std.ascii.isAlphanumeric(source[start - 1]) or source[start - 1] == '_')) start -= 1;
    return std.mem.eql(u8, source[start..end], expected);
}

fn isFieldModifier(word: []const u8) bool {
    return std.mem.eql(u8, word, "optional") or std.mem.eql(u8, word, "required") or std.mem.eql(u8, word, "repeated");
}

fn isScalarType(word: []const u8) bool {
    const words = [_][]const u8{ "bool", "bytes", "double", "fixed32", "fixed64", "float", "int32", "int64", "sfixed32", "sfixed64", "sint32", "sint64", "string", "uint32", "uint64" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
