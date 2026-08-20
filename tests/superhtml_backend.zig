const std = @import("std");
const syntax = @import("native_syntax");
const superhtml_backend = @import("native_syntax_superhtml");
const conformance = @import("support/backend_conformance.zig");
const html_recovery = @import("support/html_recovery.zig");

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

test "SuperHTML composition corpus preserves source and nested recovery" {
    const complete = @embedFile("corpus/superhtml/complete.shtml");
    const composition = @embedFile("corpus/superhtml/composition.shtml");
    const malformed = @embedFile("corpus/superhtml/malformed.shtml");

    try expectSourceRecovered(complete);
    try expectSourceRecovered(composition);
    try expectSourceRecovered(malformed);

    var composition_sink: syntax.CaptureSink = .init(std.testing.allocator, composition.len);
    defer composition_sink.deinit();
    try superhtml_backend.backend.highlight(composition, &composition_sink);
    try std.testing.expect(countScope(composition_sink.captures(), .embedded) >= 4);
    try expectCaptureText(composition, composition_sink.captures(), "\"short\"", .string);
    try expectCaptureText(composition, composition_sink.captures(), "'a > b & c'", .string);

    var malformed_sink: syntax.CaptureSink = .init(std.testing.allocator, malformed.len);
    defer malformed_sink.deinit();
    try superhtml_backend.backend.highlight(malformed, &malformed_sink);
    try expectCaptureText(malformed, malformed_sink.captures(), "@", .invalid);
    try expectCaptureText(malformed, malformed_sink.captures(), "title", .property);
}

fn expectSourceRecovered(source: []const u8) !void {
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try superhtml_backend.backend.highlight(source, &sink);

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(source, sink.captures(), std.testing.allocator, &output.writer);
    const recovered = try html_recovery.recoverSource(std.testing.allocator, output.written());
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualSlices(u8, source, recovered);
}

fn countScope(captures: []const syntax.Capture, scope: syntax.Scope) usize {
    var count: usize = 0;
    for (captures) |capture| count += @intFromBool(capture.scope == scope);
    return count;
}

fn expectCaptureText(
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
