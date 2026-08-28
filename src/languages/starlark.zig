const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
const Scope = @import("../scope.zig").Scope;
const nextNonSpace = @import("scanner_support.zig").nextNonSpace;
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;

const keywords = &.{ "and", "break", "continue", "def", "elif", "else", "for", "if", "in", "lambda", "load", "not", "or", "pass", "return" };

pub const backend: api.Backend = .init(.{ .canonical_name = "starlark", .display_name = "Starlark", .kind = .parser_backed, .support_level = .verified_structural }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{ .line_comments = &.{"#"}, .keywords = keywords, .constants = &.{"None"}, .booleans = &.{ "False", "True" }, .classify_identifiers = false });
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expected_function: bool = false,
    parameter_depth: ?usize = null,
    pending_parameters: bool = false,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len,
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            '(' => {
                if (parser.pending_parameters) parser.parameter_depth = 1 else if (parser.parameter_depth) |depth| parser.parameter_depth = depth + 1;
                parser.pending_parameters = false;
                parser.index += 1;
            },
            ')' => {
                if (parser.parameter_depth) |depth| parser.parameter_depth = if (depth == 1) null else depth - 1;
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
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_')) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (parser.expected_function) {
            try parser.sink.add(start, parser.index, .function);
            parser.expected_function = false;
            parser.pending_parameters = true;
        } else if (std.mem.eql(u8, word, "def")) {
            parser.expected_function = true;
        } else if (parser.parameter_depth != null and nextNonSpace(parser.source, parser.index) != '=') {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (previousDot(parser.source, start)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (nextNonSpace(parser.source, parser.index) == '=') {
            try parser.sink.add(start, parser.index, .property);
        } else if (!contains(keywords, word) and !std.mem.eql(u8, word, "True") and !std.mem.eql(u8, word, "False") and !std.mem.eql(u8, word, "None")) {
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
