const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.ssh_config.backend;

test "SSH config scanner is verified and conforms" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/ssh_config/complete.txt"), .required_scopes = &.{ .keyword, .property, .string, .escape, .number, .comment } },
        .malformed = .{ .source = "Host demo\n  IdentityFile \"unterminated\\q<&>\n  Port 22", .required_scopes = &.{ .keyword, .property, .string, .escape } },
        .multiline = .{ .source = "Host *.example\n  HostName %h\n  ForwardAgent yes\n", .required_scopes = &.{ .keyword, .property, .variable, .boolean } },
        .escapable = .{ .source = "HostName \"<&>\\\"'\" # note", .required_scopes = &.{ .property, .string, .escape, .comment } },
    });
}

test "SSH config assigns section directive and value roles exactly" {
    const source = "Host demo\n  HostName server.example\n  Port 2222\n  ForwardAgent yes";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "Host", .keyword);
    try expect(source, sink.captures(), "HostName", .property);
    try expect(source, sink.captures(), "2222", .number);
    try expect(source, sink.captures(), "yes", .boolean);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
