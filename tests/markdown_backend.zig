const std = @import("std");
const syntax = @import("native_syntax");
const markdown_backend = @import("native_syntax_markdown");
const conformance = @import("support/backend_conformance.zig");

test "Markdown backend metadata is stable" {
    try std.testing.expectEqualStrings("markdown", markdown_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, markdown_backend.backend.info.kind);
}

test "Markdown backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '#', ' ', 0xff, '\n' };

    try conformance.expectConforms(markdown_backend.backend, .{
        .valid = .{
            .source =
            \\# Heading
            \\
            \\> A **strong** quote with *emphasis*, ~~deleted~~ text,
            \\> [a link](https://example.com), and `code`.
            \\
            \\- [x] complete
            \\
            \\---
            \\
            \\<span>embedded</span>
            ,
            .required_scopes = &.{
                .markup_heading,
                .markup_quote,
                .markup_strong,
                .markup_emphasis,
                .markup_strikethrough,
                .markup_link,
                .markup_code,
                .markup_list,
                .special,
                .embedded,
            },
        },
        .malformed = .{
            .source = "# before\n\n[link](target) **strong** `code`\n\n[unterminated\n",
            .required_scopes = &.{ .markup_heading, .markup_link, .markup_strong, .markup_code },
        },
        .multiline = .{
            .source = "> first\n> second with *emphasis*\n",
            .required_scopes = &.{ .markup_quote, .markup_emphasis },
        },
        .escapable = .{
            .source = "# <tag title=\"x\">& 'text'</tag>\n",
            .required_scopes = &.{ .markup_heading, .embedded },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.markup_heading},
        },
    });
}

test "Markdown classifications retain original source ranges" {
    const source = "## Title\n\n1. [x] **done** and [linked](/target)\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try markdown_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "## Title", .markup_heading);
    try expectCapture(source, sink.captures(), "1.", .markup_list);
    try expectCapture(source, sink.captures(), "[x]", .markup_list);
    try expectCapture(source, sink.captures(), "**done**", .markup_strong);
    try expectCapture(source, sink.captures(), "[linked](/target)", .markup_link);
}

test "Markdown fenced code is one source-preserving capture" {
    const source = "```zig\nconst x = 1;\n```\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try markdown_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), source[0 .. source.len - 1], .markup_code);
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
