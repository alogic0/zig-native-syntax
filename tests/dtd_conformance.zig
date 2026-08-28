const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.dtd.backend;

test "DTD backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/dtd/complete.txt"), .required_scopes = &.{ .keyword, .tag, .attribute, .type, .constant, .string, .escape, .comment, .special, .punctuation } },
        .malformed = .{ .source = "<!ELEMENT open (child*\n<!ATTLIST open id ID #REQUIRED\n<!-- unterminated", .required_scopes = &.{ .keyword, .tag, .attribute, .type, .comment } },
        .multiline = .{ .source = "<!ATTLIST note\n  id ID #REQUIRED\n  status (draft|final) 'draft'>\n", .required_scopes = &.{ .tag, .attribute, .type, .constant, .keyword, .string } },
        .escapable = .{ .source = "<!ENTITY safe '<&amp;>\"'> <!-- comment -->", .required_scopes = &.{ .keyword, .constant, .string, .escape, .comment } },
        .extra_cases = &.{
            .{ .source = "<!ENTITY decimal '&#32;'> <!ENTITY hex '&#x20;'>", .required_scopes = &.{ .escape, .string } },
            .{ .source = "<![IGNORE[ <!ELEMENT hidden ANY> ]]>", .required_scopes = &.{ .keyword, .comment } },
        },
    });
}

test "DTD scanner classifies declarations content models attributes and entities exactly" {
    const source = @embedFile("corpus/dtd/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "ELEMENT", .keyword);
    try expect(source, sink.captures(), "note", .tag);
    try expect(source, sink.captures(), "to", .tag);
    try expect(source, sink.captures(), "id", .attribute);
    try expect(source, sink.captures(), "ID", .type);
    try expect(source, sink.captures(), "#REQUIRED", .keyword);
    try expect(source, sink.captures(), "draft", .constant);
    try expect(source, sink.captures(), "%shared;", .constant);
    try expect(source, sink.captures(), "%shared;", .escape);
    try expect(source, sink.captures(), "&amp;", .escape);
    try expect(source, sink.captures(), "gif", .type);
    try expect(source, sink.captures(), "<![IGNORE[\n  <!ELEMENT ignored ANY>\n]]>", .comment);
    try expect(source, sink.captures(), "<?audit source?>", .special);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
