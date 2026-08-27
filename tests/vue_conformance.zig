const std = @import("std");
const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
test "Vue composition highlights script and interpolation structure" {
    const backend = s.languages.vue.backend;
    try std.testing.expectEqual(s.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);
    const source = "<script>function greet(name) { return name; }</script><p>{{ greet(user.name) }}</p>";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "user", .variable);
    try expect(source, sink.captures(), "name", .property);
}
test "Vue backend conforms" {
    try c.expectConforms(s.languages.vue.backend, .{ .valid = .{ .source = @embedFile("corpus/vue/complete.vue"), .required_scopes = &.{ .tag, .attribute, .string, .embedded, .comment, .punctuation, .variable } }, .malformed = .{ .source = "<template><div title=\"unterminated<&>\n", .required_scopes = &.{ .tag, .attribute, .string } }, .multiline = .{ .source = "<template>\n<p>{{ value }}<&></p>\n", .required_scopes = &.{ .tag, .embedded, .variable } }, .escapable = .{ .source = "<!-- <&>\"' -->", .required_scopes = &.{.comment} } });
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
