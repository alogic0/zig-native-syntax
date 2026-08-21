const api = @import("../backend.zig");
const markup = @import("component_markup.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "astro", .display_name = "Astro", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try markup.highlight(s, k, true);
}
