const api = @import("../backend.zig");
const scanners = @import("roadmap_scanners.zig");
const structure = @import("vim_structure.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "vim", .display_name = "Vimscript", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .vim);
    try structure.highlight(source, sink);
}
