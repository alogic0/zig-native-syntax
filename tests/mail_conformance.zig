const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.mail.backend;

test "E-mail metadata and message roles are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "From: Viewer <viewer@example.test>\nSubject: Build\n\n>> quoted reply\nSee https://example.test/docs\n-- \nViewer\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "From:", .property);
    try expectCapture(source, sink.captures(), "viewer@example.test", .markup_link);
    try expectCapture(source, sink.captures(), ">> quoted reply", .markup_quote);
    try expectCapture(source, sink.captures(), "https://example.test/docs", .markup_link);
    try expectCapture(source, sink.captures(), "-- ", .special);
}

test "E-mail backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/mail/complete.txt"), .required_scopes = &.{ .property, .markup_link, .markup_quote, .punctuation, .special } },
        .malformed = .{ .source = "From viewer@example.test\n<&> body\n", .required_scopes = &.{.markup_link} },
        .multiline = .{ .source = "Subject: First\n\n> first\n>> second\n", .required_scopes = &.{ .property, .markup_quote } },
        .escapable = .{ .source = "Subject: <&>\"'\n\n> quoted viewer@example.test", .required_scopes = &.{ .property, .markup_quote, .markup_link } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/mail/thread.eml"), .required_scopes = &.{ .property, .markup_link, .markup_quote, .special } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
