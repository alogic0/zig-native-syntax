const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "swift", .display_name = "Swift", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "actor", "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "is", "let", "nonisolated", "open", "operator", "private", "protocol", "public", "repeat", "rethrows", "return", "some", "static", "struct", "subscript", "switch", "throw", "throws", "try", "typealias", "var", "where", "while" }, .types = &.{ "Any", "Bool", "Character", "Double", "Float", "Int", "Never", "String", "UInt", "Void" } });
}
