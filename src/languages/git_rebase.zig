const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "git-rebase", .display_name = "Git rebase", .kind = .lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .git_rebase);
}
