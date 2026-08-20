const std = @import("std");
const syntax = @import("native_syntax");
const ziggy_backend = @import("native_syntax_ziggy");
const conformance = @import("support/backend_conformance.zig");

test "Ziggy backend metadata is stable" {
    try std.testing.expectEqualStrings("ziggy", ziggy_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, ziggy_backend.backend.info.kind);
}

test "Ziggy backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '.', 'x', ' ', '=', ' ', 0xff, ',' };

    try conformance.expectConforms(ziggy_backend.backend, .{
        .valid = .{
            .source =
            \\// frontmatter
            \\.title = "Zine",
            \\.enabled = true,
            \\.missing = null,
            \\.count = 42,
            \\.ratio = -1.5e+2,
            \\.kind = .article,
            \\.payload = .ready(.message = "done"),
            ,
            .required_scopes = &.{
                .comment,
                .property,
                .string,
                .boolean,
                .constant,
                .number,
                .constructor,
                .operator,
                .punctuation,
            },
        },
        .malformed = .{
            .source = ".before = 1,\n.bad = ..false,\n.after = 2,",
            .required_scopes = &.{ .invalid, .property, .number },
        },
        .multiline = .{
            .source =
            \\.message = \\first line
            \\           \\second line
            \\,
            ,
            .required_scopes = &.{ .property, .string, .punctuation },
        },
        .escapable = .{
            .source = ".html = \"<b title='x'>&\\\"</b>\",",
            .required_scopes = &.{.string},
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.invalid},
        },
    });
}

test "Ziggy tokenizer classifications retain source ranges" {
    const source = ".kind = .article, .payload = .ready(false),";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try ziggy_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), ".kind", .property);
    try expectCapture(source, sink.captures(), ".article", .constant);
    try expectCapture(source, sink.captures(), ".ready", .constructor);
    try expectCapture(source, sink.captures(), "false", .boolean);
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
