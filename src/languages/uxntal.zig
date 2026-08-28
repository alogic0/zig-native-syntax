const api = @import("../backend.zig");
const scanner = @import("uxntal_scanner.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "uxntal", .display_name = "Uxntal", .kind = .lexical, .support_level = .verified_lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanner.highlight(source, sink);
}
