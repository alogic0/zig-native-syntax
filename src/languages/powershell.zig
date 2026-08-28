const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;
pub const backend: api.Backend = .init(.{ .canonical_name = "powershell", .display_name = "PowerShell", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"#"}, .block_comments = &.{.{ .open = "<#", .close = "#>" }}, .keywords = &.{ "begin", "break", "catch", "class", "continue", "data", "do", "dynamicparam", "else", "elseif", "end", "enum", "exit", "filter", "finally", "for", "foreach", "from", "function", "if", "in", "param", "process", "return", "switch", "throw", "trap", "try", "until", "using", "while", "workflow" }, .types = &.{ "bool", "byte", "char", "datetime", "decimal", "double", "float", "hashtable", "int", "long", "object", "string", "void" }, .case_insensitive = true });
    var parser: StructureParser = .{ .source = s, .sink = k };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expected: ?@import("../scope.zig").Scope = null,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len,
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn skipString(parser: *StructureParser, quote: u8) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '`' or parser.source[parser.index] == '\\') parser.index += @min(@as(usize, 2), parser.source.len - parser.index) else {
                const byte = parser.source[parser.index];
                parser.index += 1;
                if (byte == quote or byte == '\n') break;
            }
        }
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_' or parser.source[parser.index] == '-')) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
        } else if (std.ascii.eqlIgnoreCase(word, "function") or std.ascii.eqlIgnoreCase(word, "filter") or std.ascii.eqlIgnoreCase(word, "workflow")) {
            parser.expected = .function;
        } else if (std.ascii.eqlIgnoreCase(word, "class") or std.ascii.eqlIgnoreCase(word, "enum")) {
            parser.expected = .type;
        }
    }
};
