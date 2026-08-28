const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.hurl.backend;

test "Hurl metadata and request roles are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "GET https://example.test/{{user_id}}\nHTTP/1.1 200\nContent-Type: application/json\n[Asserts]\njsonpath \"$.name\" == \"viewer\"\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "GET", .keyword);
    try expectCapture(source, sink.captures(), "https://example.test/{{user_id}}", .markup_link);
    try expectCapture(source, sink.captures(), "{{user_id}}", .variable);
    try expectCapture(source, sink.captures(), "200", .number);
    try expectCapture(source, sink.captures(), "Content-Type:", .property);
    try expectCapture(source, sink.captures(), "[Asserts]", .tag);
}

test "Hurl backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/hurl/complete.txt"), .required_scopes = &.{ .keyword, .markup_link, .variable, .property, .tag, .type, .string, .escape, .number, .comment } },
        .malformed = .{ .source = "POST {{base_url}}/<&>\n[Asserts\njsonpath \"unterminated\\n", .required_scopes = &.{ .keyword, .variable, .markup_link, .type, .string, .escape } },
        .multiline = .{ .source = "GET https://example.test\nHTTP/1.1 204\n", .required_scopes = &.{ .keyword, .markup_link, .number } },
        .escapable = .{ .source = "POST https://example.test\nX-Text: \"<&>\\\"'\"\n# comment", .required_scopes = &.{ .keyword, .markup_link, .property, .string, .escape, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/hurl/api.hurl"), .required_scopes = &.{ .keyword, .markup_link, .variable, .property, .tag, .type } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
