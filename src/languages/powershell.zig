const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "powershell", .display_name = "PowerShell", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"#"}, .block_comments = &.{.{ .open = "<#", .close = "#>" }}, .keywords = &.{ "begin", "break", "catch", "class", "continue", "data", "do", "dynamicparam", "else", "elseif", "end", "enum", "exit", "filter", "finally", "for", "foreach", "from", "function", "if", "in", "param", "process", "return", "switch", "throw", "trap", "try", "until", "using", "while", "workflow" }, .types = &.{ "bool", "byte", "char", "datetime", "decimal", "double", "float", "hashtable", "int", "long", "object", "string", "void" }, .case_insensitive = true });
}
