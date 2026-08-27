const api = @import("../backend.zig");
const g = @import("generic.zig");
const structure = @import("structured_c_like.zig");
const keywords = &.{ "break", "case", "chan", "const", "continue", "default", "defer", "else", "fallthrough", "for", "func", "go", "goto", "if", "import", "interface", "map", "package", "range", "return", "select", "struct", "switch", "type", "var" };
const types = &.{ "any", "bool", "byte", "complex64", "complex128", "error", "float32", "float64", "int", "int8", "int16", "int32", "int64", "rune", "string", "uint", "uint8", "uint16", "uint32", "uint64", "uintptr" };
pub const backend: api.Backend = .init(.{ .canonical_name = "go", .display_name = "Go", .kind = .parser_backed, .support_level = .verified_structural }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = keywords, .types = types, .quotes = "\"'`", .classify_identifiers = false });
    try structure.highlight(source, sink, .{ .keywords = keywords, .builtin_types = types, .type_declarations = &.{ "type", "struct", "interface" }, .namespace_declarations = &.{"package"}, .function_declarations = &.{"func"}, .variable_declarations = &.{ "const", "var" } });
}
