const api = @import("../backend.zig");
const family = @import("elm_purescript.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "purescript",
    .display_name = "PureScript",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .purescript);
    try family.highlight(source, sink, .purescript);
}
