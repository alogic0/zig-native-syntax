const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "objc", .display_name = "Objective-C", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "interface", "implementation", "protocol", "property", "synthesize", "dynamic", "selector", "encode", "end", "class", "public", "private", "protected", "package", "try", "catch", "finally", "throw", "synchronized", "autoreleasepool", "import", "return", "if", "else", "for", "while" }, .types = &.{ "BOOL", "Class", "IMP", "SEL", "id", "instancetype", "int", "void" }, .preprocessor = true });
}
