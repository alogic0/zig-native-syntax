const api = @import("../backend.zig");
const family = @import("lisp_family.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "scheme",
    .display_name = "Scheme",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .scheme);
    try family.highlight(source, sink, .scheme);
}
