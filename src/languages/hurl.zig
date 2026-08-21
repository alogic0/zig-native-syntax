const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "hurl", .display_name = "Hurl", .kind = .lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .hurl);
}
