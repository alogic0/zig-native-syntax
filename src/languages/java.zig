const api = @import("../backend.zig");
const g = @import("generic.zig");
const structure = @import("structured_c_like.zig");
const keywords = &.{ "abstract", "assert", "break", "case", "catch", "class", "continue", "default", "do", "else", "enum", "extends", "final", "finally", "for", "if", "implements", "import", "instanceof", "interface", "native", "new", "package", "private", "protected", "public", "record", "return", "sealed", "static", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "volatile", "while", "yield" };
const types = &.{ "boolean", "byte", "char", "double", "float", "int", "long", "short", "void", "String" };
pub const backend: api.Backend = .init(.{ .canonical_name = "java", .display_name = "Java", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = keywords, .types = types, .classify_identifiers = false });
    try structure.highlight(s, k, .{ .keywords = keywords, .builtin_types = types, .modifiers = &.{ "abstract", "final", "native", "private", "protected", "public", "static", "synchronized", "transient", "volatile" }, .type_declarations = &.{ "class", "enum", "interface", "record" }, .namespace_declarations = &.{"package"} });
}
