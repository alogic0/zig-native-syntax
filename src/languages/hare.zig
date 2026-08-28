const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "hare",
    .display_name = "Hare",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .hare);
    const lexical = scanners.config(.hare);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .modifiers = &.{ "export", "static" },
        .type_declarations = &.{"type"},
        .namespace_declarations = &.{"use"},
        .function_declarations = &.{"fn"},
        .variable_declarations = &.{ "const", "let" },
        .constant_declarations = &.{"def"},
        .capitalized_types = false,
        .capitalized_braces_are_constructors = true,
        .colon_names_are_properties = true,
    });
}
