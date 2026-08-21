const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "cpp", .display_name = "C++", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "alignas", "auto", "break", "case", "catch", "class", "concept", "const", "constexpr", "continue", "co_await", "co_return", "co_yield", "decltype", "default", "delete", "do", "else", "enum", "explicit", "export", "extern", "for", "friend", "if", "inline", "namespace", "new", "noexcept", "operator", "private", "protected", "public", "requires", "return", "sizeof", "static", "struct", "switch", "template", "this", "throw", "try", "typedef", "typename", "union", "using", "virtual", "volatile", "while" }, .types = &.{ "bool", "char", "char8_t", "double", "float", "int", "long", "short", "signed", "unsigned", "void", "wchar_t", "size_t" }, .preprocessor = true });
}
