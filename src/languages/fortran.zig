const api = @import("../backend.zig");
const scanner = @import("fortran_scanner.zig");

pub const backend: api.Backend = .init(.{ .canonical_name = "fortran", .display_name = "Fortran", .kind = .lexical, .support_level = .verified_lexical }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanner.highlight(source, sink);
}
