const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "proto", .display_name = "Protocol Buffers", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "syntax", "package", "import", "option", "message", "enum", "service", "rpc", "returns", "repeated", "optional", "required", "oneof", "map", "reserved", "extend", "extensions", "to", "max", "stream" }, .types = &.{ "bool", "bytes", "double", "fixed32", "fixed64", "float", "int32", "int64", "sfixed32", "sfixed64", "sint32", "sint64", "string", "uint32", "uint64" } });
}
