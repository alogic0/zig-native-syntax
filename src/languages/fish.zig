const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "fish", .display_name = "Fish", .kind = .lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .fish);
}
