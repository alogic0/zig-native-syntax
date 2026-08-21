const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "commonlisp", .display_name = "Common Lisp", .kind = .lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .commonlisp);
}
