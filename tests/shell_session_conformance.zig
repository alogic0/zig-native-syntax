const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.shell_session.backend;

test "shell sessions highlight commands and leave output plain" {
    try std.testing.expectEqual(syntax.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "$ echo done\ndone\nuser@host:~$ printf '%s' value\nerror: $ remains output";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "$ ", .special);
    try expect(source, sink.captures(), "echo", .function);
    try expect(source, sink.captures(), "printf", .function);
    try expectNoCapture(source, sink.captures(), "done");
    try expectNoCapture(source, sink.captures(), "error: $ remains output");
}

test "shell-session backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/shell_session/complete.txt"), .required_scopes = &.{ .special, .embedded, .function, .string } },
        .malformed = .{ .source = "$ printf \"unterminated<&>\noutput\n", .required_scopes = &.{ .special, .embedded, .function, .string } },
        .multiline = .{ .source = "$ echo first\nfirst\n$ echo second\nsecond\n", .required_scopes = &.{ .special, .embedded, .function } },
        .escapable = .{ .source = "$ printf '%s' \"<&>\\\"'\"\n<&>\n", .required_scopes = &.{ .special, .embedded, .function, .string, .escape } },
    });
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectNoCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8) !void {
    const start = std.mem.lastIndexOf(u8, source, text).?;
    const end = start + text.len;
    for (captures) |capture| if (capture.span.start < end and capture.span.end > start) return error.TestUnexpectedResult;
}
