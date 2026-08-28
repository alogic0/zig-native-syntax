const std = @import("std");
const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
test "Astro composes frontmatter and expressions" {
    const backend = s.languages.astro.backend;
    try std.testing.expectEqual(s.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);
    const source = "---\nconst title = makeTitle(user.name);\n---\n<h1>{title}</h1>";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "title", .variable);
    try expect(source, sink.captures(), "makeTitle", .function);
    try expect(source, sink.captures(), "name", .property);
}
test "Astro backend conforms" {
    try c.expectConforms(s.languages.astro.backend, .{ .valid = .{ .source = @embedFile("corpus/astro/complete.astro"), .required_scopes = &.{ .special, .embedded, .tag, .attribute, .string, .comment, .punctuation, .variable } }, .malformed = .{ .source = "---\nconst x = '<&>'\n<div title=\"open\n", .required_scopes = &.{ .special, .embedded, .variable } }, .multiline = .{ .source = "---\nconst x = 1\n---\n<div><&></div>\n", .required_scopes = &.{ .special, .embedded, .tag, .variable } }, .escapable = .{ .source = "<!-- <&>\"' -->", .required_scopes = &.{.comment} } });
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
