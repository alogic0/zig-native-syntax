const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "kotlin", .display_name = "Kotlin", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "as", "break", "by", "catch", "class", "companion", "const", "constructor", "continue", "data", "do", "else", "enum", "expect", "external", "final", "finally", "for", "fun", "if", "import", "in", "infix", "inline", "interface", "internal", "is", "lateinit", "noinline", "object", "open", "operator", "out", "override", "package", "private", "protected", "public", "reified", "return", "sealed", "suspend", "tailrec", "this", "throw", "try", "typealias", "val", "var", "vararg", "when", "where", "while" }, .types = &.{ "Any", "Boolean", "Byte", "Char", "Double", "Float", "Int", "Long", "Nothing", "Short", "String", "Unit" } });
}
