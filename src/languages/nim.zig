const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "nim",
    .display_name = "Nim",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .nim);
    const lexical = scanners.config(.nim);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .modifiers = &.{ "distinct", "ref" },
        .type_declarations = &.{"type"},
        .namespace_declarations = &.{ "from", "import", "include" },
        .function_declarations = &.{ "converter", "func", "iterator", "macro", "method", "proc", "template" },
        .variable_declarations = &.{ "let", "var" },
        .constant_declarations = &.{"const"},
        .capitalized_calls_are_constructors = true,
        .colon_names_are_properties = true,
        .namespace_declarations_end_at_newline = true,
        .identifier_export_marker = true,
        .colon_properties_in_parentheses = true,
    });
    try highlightPragmas(source, sink);
}

fn highlightPragmas(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var index: usize = 0;
    while (index < source.len) {
        if (std.mem.startsWith(u8, source[index..], "#[")) {
            index = if (std.mem.indexOfPos(u8, source, index + 2, "]#")) |end| end + 2 else source.len;
        } else if (source[index] == '#') {
            index = scanner.lineEnd(source, index, source.len);
        } else if (source[index] == '"' or source[index] == '\'') {
            index = scanner.stringEnd(source, index, source[index], true);
        } else if (std.mem.startsWith(u8, source[index..], "{.")) {
            const start = index;
            index = if (std.mem.indexOfPos(u8, source, index + 2, ".}")) |end| end + 2 else source.len;
            try sink.add(start, index, .attribute);
        } else {
            index += scanner.validUtf8Length(source[index..]);
        }
    }
}
