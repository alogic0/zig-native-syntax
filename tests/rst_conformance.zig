const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.rst.backend;

test "reStructuredText metadata and focused roles are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "Viewer\n======\n.. code-block:: zig\n   :linenos:\nSee :doc:`guide` and ``render()``.\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "Viewer", .markup_heading);
    try expectCapture(source, sink.captures(), ".. code-block::", .attribute);
    try expectCapture(source, sink.captures(), ":linenos:", .property);
    try expectCapture(source, sink.captures(), ":doc:`guide`", .markup_link);
    try expectCapture(source, sink.captures(), "``render()``", .markup_code);
}

test "reStructuredText backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/rst/complete.txt"), .required_scopes = &.{ .markup_heading, .attribute, .property, .markup_link, .markup_code, .comment } },
        .malformed = .{ .source = "Title\n=====\n`unterminated <&>\n.. note::\n", .required_scopes = &.{ .markup_heading, .attribute } },
        .multiline = .{ .source = "First\n=====\n\nSecond\n------\n", .required_scopes = &.{.markup_heading} },
        .escapable = .{ .source = "``<&>\"'`` and `link <https://example.test>`_\n.. comment", .required_scopes = &.{ .markup_code, .markup_link, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/rst/guide.rst"), .required_scopes = &.{ .markup_heading, .attribute, .property, .markup_list, .markup_link } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
