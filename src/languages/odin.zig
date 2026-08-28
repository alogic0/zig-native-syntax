const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "odin",
    .display_name = "Odin",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .odin);
    const lexical = scanners.config(.odin);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .type_declarations = &.{ "bit_field", "enum", "struct", "union" },
        .namespace_declarations = &.{ "import", "package" },
        .function_declarations = &.{"proc"},
        .capitalized_calls_are_constructors = true,
        .type_body_fields_before_type = true,
        .capitalized_braces_are_constructors = true,
        .colon_names_are_properties = true,
        .namespace_declarations_end_at_newline = true,
        .double_colon_declarations = true,
    });
}
