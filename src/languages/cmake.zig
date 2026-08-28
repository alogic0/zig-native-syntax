const api = @import("../backend.zig");
const scanner = @import("cmake_scanner.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "cmake", .display_name = "CMake", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanner.highlight(source, sink);
}
