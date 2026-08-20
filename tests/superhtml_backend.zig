const std = @import("std");
const syntax = @import("native_syntax");
const superhtml_backend = @import("native_syntax_superhtml");
const conformance = @import("support/backend_conformance.zig");

test "SuperHTML backend metadata is stable" {
    try std.testing.expectEqualStrings("superhtml", superhtml_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.composed, superhtml_backend.backend.info.kind);
}

test "SuperHTML backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '<', 'p', ' ', ':', 'i', 'f', '=', '"', '$', 'x', '.', 0xff, '"', '>' };
    const extra_cases = [_]conformance.Case{
        .{
            .source = "<div :if=\"$page.ok(@\" :text=\"$page.title\"></div>",
            .required_scopes = &.{ .tag, .special, .embedded, .invalid, .variable },
        },
        .{
            .source = "<div :else data-value=\"plain\"></div>",
            .required_scopes = &.{ .special, .string },
        },
    };

    try conformance.expectConforms(superhtml_backend.backend, .{
        .valid = .{
            .source = "<h1 :text=\"$page.title.trim()\"></h1><a href=\"$page.link()\">Open</a>",
            .required_scopes = &.{
                .tag,
                .attribute,
                .special,
                .embedded,
                .variable,
                .property,
                .function,
                .punctuation,
            },
        },
        .malformed = .{
            .source = "<div :if=\"$page.good(@)\" broken=\"unterminated",
            .required_scopes = &.{ .special, .embedded, .invalid },
        },
        .multiline = .{
            .source =
            \\<div
            \\  :if="$page.enabled(
            \\    true
            \\  )"
            \\  :text="$page.title">
            \\</div>
            ,
            .required_scopes = &.{ .special, .embedded, .function, .boolean },
        },
        .escapable = .{
            .source = "<p :text=\"$page.value('&amp;<tag>')\" title=\"'&amp;&lt;&gt;&quot;\"></p>",
            .required_scopes = &.{ .embedded, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .embedded, .invalid },
        },
        .extra_cases = &extra_cases,
    });
}

test "SuperHTML expression contents do not retain parent string scope" {
    const source = "<h1 :text=\"$page.title\"></h1>";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try superhtml_backend.backend.highlight(source, &sink);

    const expression_start = std.mem.indexOf(u8, source, "$page").?;
    const expression_end = expression_start + "$page.title".len;
    try expectCaptureAt(sink.captures(), expression_start, expression_end, .embedded);
    try expectCaptureAt(sink.captures(), expression_start, expression_start + 1, .special);
    try expectNoScopeAt(sink.captures(), expression_start, .string);
    try expectScopeAt(sink.captures(), expression_start - 1, .string);
    try expectScopeAt(sink.captures(), expression_end, .string);
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

fn expectScopeAt(captures: []const syntax.Capture, offset: usize, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            capture.span.start <= offset and
            capture.span.end > offset) return;
    }
    return error.TestExpectedEqual;
}

fn expectNoScopeAt(captures: []const syntax.Capture, offset: usize, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            capture.span.start <= offset and
            capture.span.end > offset) return error.TestUnexpectedResult;
    }
}
