const api = @import("../backend.zig");
const ml = @import("ml_family.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "ocaml", .display_name = "OCaml", .kind = .parser_backed }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try ml.highlight(source, sink, .ocaml);
}
