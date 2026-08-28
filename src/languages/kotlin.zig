const api = @import("../backend.zig");
const g = @import("generic.zig");
const structure = @import("structured_c_like.zig");
const keywords = &.{ "as", "break", "by", "catch", "class", "companion", "const", "constructor", "continue", "data", "do", "else", "enum", "expect", "external", "final", "finally", "for", "fun", "if", "import", "in", "infix", "inline", "interface", "internal", "is", "lateinit", "noinline", "object", "open", "operator", "out", "override", "package", "private", "protected", "public", "reified", "return", "sealed", "suspend", "tailrec", "this", "throw", "try", "typealias", "val", "var", "vararg", "when", "where", "while" };
const types = &.{ "Any", "Boolean", "Byte", "Char", "Double", "Float", "Int", "Long", "Nothing", "Short", "String", "Unit" };
pub const backend: api.Backend = .init(.{ .canonical_name = "kotlin", .display_name = "Kotlin", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = keywords, .types = types, .classify_identifiers = false });
    try structure.highlight(s, k, .{ .keywords = keywords, .builtin_types = types, .modifiers = &.{ "data", "external", "final", "inline", "internal", "open", "override", "private", "protected", "public", "sealed", "suspend", "tailrec" }, .type_declarations = &.{ "class", "enum", "interface", "object", "typealias" }, .namespace_declarations = &.{"package"}, .function_declarations = &.{"fun"}, .variable_declarations = &.{ "val", "var" } });
}
