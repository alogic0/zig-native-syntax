const api = @import("../backend.zig");
const scanner = @import("dtd_scanner.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "dtd", .display_name = "DTD", .kind = .lexical, .support_level = .verified_lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanner.highlight(source, sink);
}
