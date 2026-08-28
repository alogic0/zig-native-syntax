const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "c3",
    .display_name = "C3",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .c3);
    const lexical = scanners.config(.c3);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .modifiers = &.{ "const", "extern", "inline", "static" },
        .type_declarations = &.{ "bitstruct", "enum", "fault", "interface", "struct", "union" },
        .namespace_declarations = &.{ "import", "module" },
        .type_body_declarations_are_properties = true,
    });
}
