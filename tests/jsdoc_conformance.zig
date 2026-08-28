const std = @import("std");
const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");

test "JSDoc metadata and documentation roles are stable" {
    const backend = s.languages.jsdoc.backend;
    try std.testing.expectEqual(s.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "/** @param {Array<{name: string}>} [items=[]] See {@link render}. */";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "@param", .attribute);
    try expectCapture(source, sink.captures(), "{Array<{name: string}>}", .type);
    try expectCapture(source, sink.captures(), "[items=[]]", .parameter);
    try expectCapture(source, sink.captures(), "{@link render}", .markup_link);
}

test "JSDoc backend conforms" {
    try c.expectConforms(s.languages.jsdoc.backend, .{ .valid = .{ .source = @embedFile("corpus/jsdoc/complete.jsdoc"), .required_scopes = &.{ .comment, .documentation, .attribute, .type, .parameter, .markup_code } }, .malformed = .{ .source = "/** @param {string value <&>", .required_scopes = &.{ .comment, .documentation, .attribute, .type } }, .multiline = .{ .source = "/**\n * @returns {string}\n", .required_scopes = &.{ .comment, .documentation, .attribute, .type } }, .escapable = .{ .source = "/** <&>\"' `code` {@link value} */", .required_scopes = &.{ .comment, .markup_code, .markup_link } }, .extra_cases = &.{.{ .source = @embedFile("corpus/jsdoc/component.jsdoc"), .required_scopes = &.{ .attribute, .type, .parameter, .markup_link } }} });
}

fn expectCapture(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
