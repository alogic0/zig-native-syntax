const std = @import("std");
const syntax = @import("native_syntax");
const scripty_backend = @import("native_syntax_scripty");
const conformance = @import("support/backend_conformance.zig");

test "Scripty backend metadata is stable" {
    try std.testing.expectEqualStrings("scripty", scripty_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, scripty_backend.backend.info.kind);
}

test "Scripty backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '$', 'p', 'a', 'g', 'e', '.', 0xff };
    const extra_cases = [_]conformance.Case{
        .{
            .source = "$page.title.",
            .required_scopes = &.{ .variable, .property, .invalid },
        },
        .{
            .source = "$page.is('unterminated",
            .required_scopes = &.{ .function, .invalid },
        },
        .{
            .source = "$page.ok()\n",
            .required_scopes = &.{ .variable, .function, .punctuation },
        },
    };

    try conformance.expectConforms(scripty_backend.backend, .{
        .valid = .{
            .source = "$page.title.trim().then(\"yes\", false, -12.5)",
            .required_scopes = &.{
                .special,
                .variable,
                .property,
                .function,
                .string,
                .boolean,
                .number,
                .punctuation,
            },
        },
        .malformed = .{
            .source = "$page.good().bad(@, 'still highlighted')",
            .required_scopes = &.{ .function, .invalid, .string },
        },
        .multiline = .{
            .source =
            \\$page.has(
            \\    true,
            \\    12,
            \\    'value'
            \\)
            ,
            .required_scopes = &.{ .function, .boolean, .number, .string },
        },
        .escapable = .{
            .source = "$page.is(\"<tag>&'\\\"\")",
            .required_scopes = &.{ .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.invalid},
        },
        .extra_cases = &extra_cases,
    });
}

test "Scripty parser context distinguishes paths and calls" {
    const source = "$page.author.name.is('Oleg')";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try scripty_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "page", .variable);
    try expectCapture(source, sink.captures(), "author", .property);
    try expectCapture(source, sink.captures(), "name", .property);
    try expectCapture(source, sink.captures(), "is", .function);
    try expectCapture(source, sink.captures(), "'Oleg'", .string);
}

test "Scripty lexical recovery continues after a parser error" {
    const source = "$page.call(@, \"after\")";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try scripty_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "@", .invalid);
    try expectCapture(source, sink.captures(), "\"after\"", .string);
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
