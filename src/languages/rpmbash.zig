const api = @import("../backend.zig");
const bash = @import("bash.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "rpmbash",
    .display_name = "RPM Bash",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try bash.backend.highlight(source, sink);
}
