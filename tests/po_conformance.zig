const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.po.backend;

test "Gettext PO scanner is verified and conforms" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/po/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .comment, .attribute, .number, .punctuation } },
        .malformed = .{ .source = "msgid \"unterminated\\q<&>\nmsgstr \"value\"", .required_scopes = &.{ .keyword, .string, .escape } },
        .multiline = .{ .source = "msgid \"\"\n\"first <&>\"\n\"second\"\nmsgstr \"value\"\n", .required_scopes = &.{ .keyword, .string } },
        .escapable = .{ .source = "msgid \"<&>\\\"'\"\n# note", .required_scopes = &.{ .keyword, .string, .escape, .comment } },
    });
}

test "Gettext PO assigns directive plural flag and string roles exactly" {
    const source = "#, fuzzy\nmsgid_plural \"files\"\nmsgstr[2] \"Dateien\"";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "#, fuzzy", .attribute);
    try expect(source, sink.captures(), "msgid_plural", .keyword);
    try expect(source, sink.captures(), "2", .number);
    try expect(source, sink.captures(), "\"Dateien\"", .string);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
