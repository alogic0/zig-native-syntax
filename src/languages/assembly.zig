const api = @import("../backend.zig");
const family = @import("assembly_family.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "asm", .display_name = "Assembly", .kind = .lexical, .support_level = .verified_lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try family.highlight(s, k, .gas);
}
