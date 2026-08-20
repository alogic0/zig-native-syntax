const std = @import("std");
const syntax = @import("native_syntax");
const html_backend = @import("native_syntax_html");
const conformance = @import("support/backend_conformance.zig");

test "HTML backend metadata is stable" {
    try std.testing.expectEqualStrings("html", html_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, html_backend.backend.info.kind);
}

test "HTML backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '<', 'p', '>', 0xff, '<', '/', 'p', '>' };
    const extra_cases = [_]conformance.Case{
        .{
            .source = "<script>if (a < b) alert('&amp;');</script><style>a>b{}</style>",
            .required_scopes = &.{ .tag, .punctuation },
        },
        .{
            .source = "<p title='unterminated",
            .required_scopes = &.{ .tag, .invalid },
        },
    };

    try conformance.expectConforms(html_backend.backend, .{
        .valid = .{
            .source = "<!doctype html><article class=lead data-name=\"Zine\">Hello &amp; bye</article>",
            .required_scopes = &.{
                .keyword,
                .tag,
                .attribute,
                .string,
                .escape,
                .operator,
                .punctuation,
            },
        },
        .malformed = .{
            .source = "<div good=ok broken=>after<!-- unfinished",
            .required_scopes = &.{ .tag, .attribute, .invalid, .comment },
        },
        .multiline = .{
            .source =
            \\<!-- heading -->
            \\<section
            \\  id="main">
            \\  text
            \\</section>
            ,
            .required_scopes = &.{ .comment, .tag, .attribute, .string },
        },
        .escapable = .{
            .source = "<p title=\"'&amp;&lt;&gt;&quot;\">&lt;b&gt;</p>",
            .required_scopes = &.{ .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.tag},
        },
        .extra_cases = &extra_cases,
    });
}

test "HTML adapter retains structural source ranges" {
    const source = "<img alt='logo' disabled />";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try html_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "img", .tag);
    try expectCapture(source, sink.captures(), "alt", .attribute);
    try expectCapture(source, sink.captures(), "'logo'", .string);
    try expectCapture(source, sink.captures(), "disabled", .attribute);
    try expectCapture(source, sink.captures(), "/", .punctuation);
}

test "HTML corpus remains source-preserving" {
    const source = @embedFile("corpus/html/complete.html");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try html_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "article", .tag);
    try expectCapture(source, sink.captures(), "data-visible", .attribute);
    try expectCapture(source, sink.captures(), "&amp;", .escape);
}

test "HTML leaves script and style contents unclassified" {
    const source = "<script>if (a < b) text = '&amp;';</script><style>a>b{}</style>";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try html_backend.backend.highlight(source, &sink);

    const script_body_start = std.mem.indexOf(u8, source, "if (").?;
    const script_body_end = std.mem.indexOf(u8, source, "</script>").?;
    const style_body_start = std.mem.indexOf(u8, source, "a>b{}").?;
    const style_body_end = std.mem.indexOf(u8, source, "</style>").?;
    try expectNoCaptureInside(sink.captures(), script_body_start, script_body_end);
    try expectNoCaptureInside(sink.captures(), style_body_start, style_body_end);
    try expectCaptureAt(sink.captures(), script_body_end + 2, script_body_end + 8, .tag);
    try expectCaptureAt(sink.captures(), style_body_end + 2, style_body_end + 7, .tag);
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

fn expectNoCaptureInside(
    captures: []const syntax.Capture,
    start: usize,
    end: usize,
) !void {
    for (captures) |capture| {
        if (capture.span.start < end and capture.span.end > start) {
            return error.TestUnexpectedResult;
        }
    }
}

fn expectCaptureAt(
    captures: []const syntax.Capture,
    start: usize,
    end: usize,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            capture.span.start == start and
            capture.span.end == end) return;
    }
    return error.TestExpectedEqual;
}
