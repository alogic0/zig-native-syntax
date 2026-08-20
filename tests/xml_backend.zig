const std = @import("std");
const syntax = @import("native_syntax");
const xml_backend = @import("native_syntax_xml");
const conformance = @import("support/backend_conformance.zig");

test "XML backend metadata is stable" {
    try std.testing.expectEqualStrings("xml", xml_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, xml_backend.backend.info.kind);
}

test "XML backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '<', 'x', '>', 0xff, '<', '/', 'x', '>' };

    try conformance.expectConforms(xml_backend.backend, .{
        .valid = .{
            .source = "<?xml version=\"1.0\"?><catalog><item id='7'>A &amp; B</item></catalog>",
            .required_scopes = &.{ .special, .tag, .attribute, .string, .escape, .punctuation },
        },
        .malformed = .{
            .source = "<catalog><item id=></catalog>",
            .required_scopes = &.{ .tag, .attribute, .invalid },
        },
        .multiline = .{
            .source =
            \\<!-- inventory -->
            \\<catalog>
            \\  <item id="1" />
            \\</catalog>
            ,
            .required_scopes = &.{ .comment, .tag, .attribute, .string },
        },
        .escapable = .{
            .source = "<text value=\"'&amp;&lt;&gt;&quot;\">&lt;x&gt;</text>",
            .required_scopes = &.{ .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.tag},
        },
    });
}

test "XML mode keeps self-closing syntax and case-sensitive names" {
    const source = "<Feed><Entry Key=\"A\" /></Feed>";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try xml_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "Feed", .tag);
    try expectCapture(source, sink.captures(), "Entry", .tag);
    try expectCapture(source, sink.captures(), "Key", .attribute);
    try expectCapture(source, sink.captures(), "\"A\"", .string);
}

test "XML corpus remains source-preserving" {
    const source = @embedFile("corpus/xml/complete.xml");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try xml_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "catalog", .tag);
    try expectCapture(source, sink.captures(), "xmlns", .attribute);
    try expectCapture(source, sink.captures(), "&amp;", .escape);
}

fn expectCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
