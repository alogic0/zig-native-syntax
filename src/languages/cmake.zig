const api = @import("../backend.zig");
const generic = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "cmake", .display_name = "CMake", .kind = .lexical }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{ .line_comments = &.{"#"}, .keywords = &.{ "if", "else", "elseif", "endif", "foreach", "endforeach", "function", "endfunction", "macro", "endmacro", "while", "endwhile", "include", "return" }, .booleans = &.{ "ON", "OFF", "TRUE", "FALSE", "YES", "NO" }, .constants = &.{ "NOTFOUND", "IGNORE" }, .case_insensitive = true });
}
