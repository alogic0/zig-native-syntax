const std = @import("std");
const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");

test "Regex metadata and focused roles are stable" {
    const backend = s.languages.regex.backend;
    try std.testing.expectEqual(s.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "(?<word>[\\p{L}_][\\w-]*?)(?:\\s+)(?<count>\\d{2,4})";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "word", .label);
    try expectCapture(source, sink.captures(), "count", .label);
    try expectCapture(source, sink.captures(), "\\p", .escape);
    try expectCapture(source, sink.captures(), "{2,4}", .operator);
}

test "Regex backend conforms" {
    try c.expectConforms(s.languages.regex.backend, .{ .valid = .{ .source = @embedFile("corpus/regex/complete.regex"), .required_scopes = &.{ .escape, .string, .operator, .special, .punctuation, .label } }, .malformed = .{ .source = "^(?<name>unterminated[<&>\\d+", .required_scopes = &.{ .special, .label, .string } }, .multiline = .{ .source = "^first$\n^second$", .required_scopes = &.{.special} }, .escapable = .{ .source = "[<&>\"'\\w]+", .required_scopes = &.{ .string, .escape, .operator } }, .extra_cases = &.{.{ .source = @embedFile("corpus/regex/routes.regex"), .required_scopes = &.{ .label, .escape, .operator } }} });
}

fn expectCapture(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
