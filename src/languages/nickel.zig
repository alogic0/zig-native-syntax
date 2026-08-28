const api = @import("../backend.zig");
const structure = @import("nickel_structure.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "nickel", .display_name = "Nickel", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .nickel);
    try structure.highlight(source, sink);
}
