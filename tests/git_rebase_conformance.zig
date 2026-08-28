const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.git_rebase.backend;

test "Git rebase composition is verified and conforms" {
    try std.testing.expectEqual(syntax.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/git_rebase/complete.txt"), .required_scopes = &.{ .keyword, .constant, .string, .comment, .embedded, .function } },
        .malformed = .{ .source = "pick\nexec echo \"unterminated<&>\n", .required_scopes = &.{ .keyword, .embedded, .function, .string } },
        .multiline = .{ .source = "pick abc123 first\nexec printf '%s\\n' <&>\n# note\n", .required_scopes = &.{ .keyword, .constant, .string, .embedded, .function, .comment } },
        .escapable = .{ .source = "exec echo \"<&>\\\"'\" # note", .required_scopes = &.{ .keyword, .embedded, .function, .string, .escape, .comment } },
    });
}

test "Git rebase assigns command object label and shell roles exactly" {
    const source = "pick abc123 render safely\nlabel base\nexec echo done";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "pick", .keyword);
    try expect(source, sink.captures(), "abc123", .constant);
    try expect(source, sink.captures(), "render safely", .string);
    try expect(source, sink.captures(), "base", .label);
    try expect(source, sink.captures(), "echo", .function);
    try expect(source, sink.captures(), "echo done", .embedded);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
