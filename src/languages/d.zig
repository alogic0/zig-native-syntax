const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "d",
    .display_name = "D",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .d);
    const lexical = scanners.config(.d);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .modifiers = &.{ "abstract", "auto", "const", "deprecated", "export", "extern", "final", "immutable", "inout", "lazy", "nothrow", "out", "override", "private", "protected", "public", "pure", "ref", "scope", "shared", "static", "synchronized" },
        .type_declarations = &.{ "class", "enum", "interface", "struct", "union" },
        .namespace_declarations = &.{ "import", "module" },
        .capitalized_calls_are_constructors = true,
        .type_body_declarations_are_properties = true,
    });
}
