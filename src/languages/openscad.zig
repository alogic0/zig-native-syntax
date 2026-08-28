const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("structured_c_like.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "openscad",
    .display_name = "OpenSCAD",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .openscad);
    const lexical = scanners.config(.openscad);
    try structure.highlight(source, sink, .{
        .keywords = lexical.keywords,
        .builtin_types = lexical.types,
        .function_declarations = &.{ "function", "module" },
        .binding_introducers = &.{ "assign", "for", "intersection_for", "let" },
        .capitalized_types = false,
        .equals_properties_in_calls = true,
    });
}
