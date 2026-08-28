const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.comment.backend;

test "comment-tag backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/comment/complete.txt"),
            .required_scopes = &.{ .special, .constant, .punctuation, .number, .string, .markup_link },
        },
        .malformed = .{
            .source = "FIXME(unclosed <&>",
            .required_scopes = &.{ .special, .constant, .punctuation },
        },
        .multiline = .{
            .source = "NOTE: first\nBUG: second\n",
            .required_scopes = &.{ .special, .punctuation },
        },
        .escapable = .{
            .source = "TODO: preserve <unsafe>& \"' at https://example.test",
            .required_scopes = &.{ .special, .string, .markup_link },
        },
        .extra_cases = &.{
            .{ .source = "plain comment text", .required_scopes = &.{} },
            .{ .source = "WIP(user): issue #42", .required_scopes = &.{ .special, .constant, .number } },
        },
    });
}

test "comment-tag scanner classifies tags users issues and URLs exactly" {
    const source = @embedFile("corpus/comment/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "TODO", .special);
    try expect(source, sink.captures(), "alice", .constant);
    try expect(source, sink.captures(), "#123", .number);
    try expect(source, sink.captures(), "https://example.test/docs", .string);
    try expect(source, sink.captures(), "https://example.test/docs", .markup_link);
    try expect(source, sink.captures(), "FIXME", .special);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
