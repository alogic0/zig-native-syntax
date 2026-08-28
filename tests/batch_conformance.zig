const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.batch.backend;

test "Batch variables, labels, and comments are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "@echo off\n:: note\nset NAME=demo\ngoto :done\n:done\necho %NAME% !COUNT! %1";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), ":: note", .comment);
    try expect(source, sink.captures(), ":done", .label);
    try expect(source, sink.captures(), "%NAME%", .variable);
    try expect(source, sink.captures(), "!COUNT!", .variable);
    try expect(source, sink.captures(), "%1", .variable);
}

test "Batch backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/batch/complete.bat"), .required_scopes = &.{ .keyword, .comment, .label, .variable, .string, .escape, .number, .operator, .punctuation } },
        .malformed = .{ .source = "set VALUE=%OPEN\necho \"unterminated<&>\n", .required_scopes = &.{ .keyword, .variable, .string } },
        .multiline = .{ .source = "set FIRST=1\nset SECOND=2\n", .required_scopes = &.{ .keyword, .number } },
        .escapable = .{ .source = "echo \"<&>^\"'\" REM comment", .required_scopes = &.{ .keyword, .string, .escape } },
    });
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
