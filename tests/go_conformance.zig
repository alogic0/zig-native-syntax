const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Go backend is structural" {
    const backend = s.languages.go.backend;
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);
    const source = "package demo\ntype Item struct { Value int }\nfunc add(lhs int, rhs int) int { return helper(lhs + rhs) }";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "demo", .namespace);
    try expect(source, sink.captures(), "Item", .type);
    try expect(source, sink.captures(), "add", .function);
    try expect(source, sink.captures(), "lhs", .parameter);
    try expect(source, sink.captures(), "helper", .function);
}
test "Go backend conforms" {
    try h.expect(s.languages.go.backend, @embedFile("corpus/go/complete.go"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function }, "var x = \"<&>\\\"'\" // comment");
}
fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
