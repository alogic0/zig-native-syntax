const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "ruby", .display_name = "Ruby", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"#"}, .keywords = &.{ "alias", "and", "begin", "break", "case", "class", "def", "defined", "do", "else", "elsif", "end", "ensure", "for", "if", "in", "module", "next", "not", "or", "redo", "rescue", "retry", "return", "self", "super", "then", "undef", "unless", "until", "when", "while", "yield" }, .constants = &.{"nil"}, .at_scope = .variable });
    var parser: StructureParser = .{ .source = s, .sink = k };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expected: ?@import("../scope.zig").Scope = null,
    parameter_depth: usize = 0,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len,
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            '(' => {
                parser.parameter_depth += 1;
                parser.index += 1;
            },
            ')' => {
                parser.parameter_depth -|= 1;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn skipString(parser: *StructureParser, quote: u8) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') parser.index += @min(@as(usize, 2), parser.source.len - parser.index) else {
                const byte = parser.source[parser.index];
                parser.index += 1;
                if (byte == quote or byte == '\n') break;
            }
        }
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_' or parser.source[parser.index] == '?' or parser.source[parser.index] == '!')) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
        } else if (std.mem.eql(u8, word, "def")) {
            parser.expected = .function;
        } else if (std.mem.eql(u8, word, "class")) {
            parser.expected = .type;
        } else if (std.mem.eql(u8, word, "module")) {
            parser.expected = .namespace;
        } else if (parser.parameter_depth > 0) {
            try parser.sink.add(start, parser.index, .parameter);
        }
    }
};

fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
