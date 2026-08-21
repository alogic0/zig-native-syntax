const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "java", .display_name = "Java", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "abstract", "assert", "break", "case", "catch", "class", "continue", "default", "do", "else", "enum", "extends", "final", "finally", "for", "if", "implements", "import", "instanceof", "interface", "native", "new", "package", "private", "protected", "public", "record", "return", "sealed", "static", "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "volatile", "while", "yield" }, .types = &.{ "boolean", "byte", "char", "double", "float", "int", "long", "short", "void", "String" } });
}
