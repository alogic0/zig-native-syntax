const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "v",
    .display_name = "V",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .v);
    const lexical = scanners.config(.v);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .modifiers = &.{ "mut", "pub", "shared" },
        .type_declarations = &.{ "enum", "interface", "struct", "type", "union" },
        .namespace_declarations = &.{ "import", "module" },
        .function_declarations = &.{"fn"},
        .variable_declarations = &.{"const"},
        .capitalized_calls_are_constructors = true,
        .function_receiver_before_name = true,
        .type_body_fields_before_type = true,
        .capitalized_braces_are_constructors = true,
        .colon_names_are_properties = true,
        .namespace_declarations_end_at_newline = true,
    });
}
