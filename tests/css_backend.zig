const std = @import("std");
const syntax = @import("native_syntax");
const css_backend = @import("native_syntax_css");
const conformance = @import("support/backend_conformance.zig");

test "CSS backend metadata is stable" {
    try std.testing.expectEqualStrings("css", css_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, css_backend.backend.info.kind);
}

test "CSS backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '.', 0xff, ' ', '{', ' ', 'x', ':', '1', '}' };
    const extra_cases = [_]conformance.Case{
        .{
            .source = ".card[data-kind='note']:hover { color: red; }",
            .required_scopes = &.{ .tag, .string, .property, .constant },
        },
        .{
            .source = ".broken { background: url(unclosed",
            .required_scopes = &.{ .property, .invalid },
        },
        .{
            .source = "/* unfinished <style>&'\"",
            .required_scopes = &.{.comment},
        },
    };

    try conformance.expectConforms(css_backend.backend, .{
        .valid = .{
            .source =
            \\@media (min-width: 40rem) {
            \\  article.card:hover {
            \\    --gap: 1.5rem;
            \\    color: #aabbcc;
            \\    background: url(images/bg.png);
            \\  }
            \\}
            ,
            .required_scopes = &.{
                .keyword,
                .tag,
                .property,
                .constant,
                .function,
                .string,
                .number,
                .type,
                .operator,
                .punctuation,
            },
        },
        .malformed = .{
            .source = ".before { color: red; content: \"unterminated\n.after { width: 2px; }",
            .required_scopes = &.{ .tag, .property, .invalid, .number, .type },
        },
        .multiline = .{
            .source =
            \\/* layout */
            \\main {
            \\  display: grid;
            \\  gap: 2rem;
            \\}
            ,
            .required_scopes = &.{ .comment, .tag, .property, .constant, .number },
        },
        .escapable = .{
            .source = ".html::before { content: \"<tag>&'\\\"\"; }",
            .required_scopes = &.{ .tag, .property, .string },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.tag},
        },
        .extra_cases = &extra_cases,
    });
}

test "CSS tokenizer ranges distinguish declarations and values" {
    const source = "a:hover { margin: -1.5rem 20%; color: red; background: url(bg.png); }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try css_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "a", .tag);
    try expectCapture(source, sink.captures(), "margin", .property);
    try expectCapture(source, sink.captures(), "-1.5", .number);
    try expectCapture(source, sink.captures(), "rem", .type);
    try expectCapture(source, sink.captures(), "20%", .number);
    try expectCapture(source, sink.captures(), "red", .constant);
    try expectCapture(source, sink.captures(), "url", .function);
    try expectCapture(source, sink.captures(), "bg.png", .string);
}

test "CSS custom properties differ from references in values" {
    const source = ":root { --gap: 1rem; gap: var(--gap); }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try css_backend.backend.highlight(source, &sink);

    const declaration = std.mem.indexOf(u8, source, "--gap").?;
    const reference = std.mem.lastIndexOf(u8, source, "--gap").?;
    try expectCaptureAt(sink.captures(), declaration, declaration + 5, .property);
    try expectCaptureAt(sink.captures(), reference, reference + 5, .constant);
}

test "CSS comment scanner ignores markers inside strings" {
    const source = ".x { content: \"not /* comment */\"; } /* comment */";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try css_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "\"not /* comment */\"", .string);
    try expectCapture(source, sink.captures(), "/* comment */", .comment);
    const false_comment = std.mem.indexOf(u8, source, "/* comment */").?;
    try expectNoCaptureAt(sink.captures(), false_comment, false_comment + 13, .comment);
}

test "CSS corpus remains source-preserving" {
    const source = @embedFile("corpus/css/complete.css");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try css_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "/* Native highlighting fixture. */", .comment);
    try expectCapture(source, sink.captures(), "grid-template-columns", .property);
    try expectCapture(source, sink.captures(), "minmax", .function);
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

fn expectNoCaptureAt(
    captures: []const syntax.Capture,
    start: usize,
    end: usize,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            capture.span.start == start and
            capture.span.end == end) return error.TestUnexpectedResult;
    }
}
