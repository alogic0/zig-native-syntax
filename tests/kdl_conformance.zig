const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.kdl.backend;

test "KDL scanner is verified and conforms" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/kdl/complete.txt"), .required_scopes = &.{ .tag, .property, .string, .escape, .number, .boolean, .comment, .operator } },
        .malformed = .{ .source = "node key=\"unterminated\\q<&>\nnext value=true", .required_scopes = &.{ .tag, .property, .string, .escape } },
        .multiline = .{ .source = "root {\n child text=r#\"<&>\"#\n}\n", .required_scopes = &.{ .tag, .property, .string, .punctuation } },
        .escapable = .{ .source = "node text=\"<&>\\\"'\" // note", .required_scopes = &.{ .tag, .property, .string, .escape, .comment } },
    });
}

test "KDL assigns node property and primitive roles exactly" {
    const source = "service image=\"demo\" replicas=2 enabled=true";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "service", .tag);
    try expect(source, sink.captures(), "image", .property);
    try expect(source, sink.captures(), "2", .number);
    try expect(source, sink.captures(), "true", .boolean);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
