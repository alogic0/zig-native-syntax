const api = @import("../backend.zig");
const g = @import("generic.zig");
const structure = @import("structured_c_like.zig");
const keywords = &.{ "actor", "as", "associatedtype", "break", "case", "catch", "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension", "fallthrough", "for", "func", "guard", "if", "import", "in", "init", "inout", "internal", "is", "let", "nonisolated", "open", "operator", "private", "protocol", "public", "repeat", "rethrows", "return", "some", "static", "struct", "subscript", "switch", "throw", "throws", "try", "typealias", "var", "where", "while" };
const types = &.{ "Any", "Bool", "Character", "Double", "Float", "Int", "Never", "String", "UInt", "Void" };
pub const backend: api.Backend = .init(.{ .canonical_name = "swift", .display_name = "Swift", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = keywords, .types = types, .classify_identifiers = false });
    try structure.highlight(s, k, .{ .keywords = keywords, .builtin_types = types, .modifiers = &.{ "internal", "nonisolated", "open", "private", "public", "static" }, .type_declarations = &.{ "actor", "class", "enum", "protocol", "struct", "typealias" }, .function_declarations = &.{"func"}, .variable_declarations = &.{ "let", "var" } });
}
