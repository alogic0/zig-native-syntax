const std = @import("std");
const syntax = @import("native_syntax");
const schema_backend = @import("native_syntax_ziggy_schema");
const conformance = @import("support/backend_conformance.zig");

test "Ziggy Schema backend metadata is stable" {
    try std.testing.expectEqualStrings("ziggy-schema", schema_backend.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, schema_backend.backend.info.kind);
}

test "Ziggy Schema backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '$', ' ', '=', ' ', 0xff };

    try conformance.expectConforms(schema_backend.backend, .{
        .valid = .{
            .source =
            \\/// Site frontmatter.
            \\$ = Frontmatter
            \\
            \\struct Frontmatter {
            \\    title: bytes,
            \\    draft: ?bool,
            \\    tags: []bytes,
            \\    metadata: ?{:}bytes,
            \\    payload: Payload,
            \\}
            \\
            \\union Payload {
            \\    text: bytes,
            \\    empty,
            \\}
            ,
            .required_scopes = &.{
                .comment,
                .documentation,
                .special,
                .operator,
                .keyword,
                .type,
                .builtin,
                .property,
                .punctuation,
            },
        },
        .malformed = .{
            .source =
            \\$ = Root
            \\struct Root {
            \\    before: bool
            \\    broken: @wrong,
            \\    after: int,
            \\}
            ,
            .required_scopes = &.{ .invalid, .property, .builtin },
        },
        .multiline = .{
            .source =
            \\$ = Root
            \\struct Root {
            \\    /// A documented field.
            \\    value: ?float,
            \\}
            ,
            .required_scopes = &.{ .documentation, .property, .type },
        },
        .escapable = .{
            .source =
            \\/// <tag title="x">&' content.
            \\$ = any
            ,
            .required_scopes = &.{ .comment, .builtin },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.invalid},
        },
    });
}

test "Ziggy Schema AST adds declaration and field context" {
    const source =
        \\$ = Article
        \\struct Article {
        \\    title: bytes,
        \\}
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try schema_backend.backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "Article", .type);
    try expectCapture(source, sink.captures(), "title", .property);
    try expectNoCapture(source, sink.captures(), "title", .type);
    try expectCapture(source, sink.captures(), "bytes", .builtin);
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

fn expectNoCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            std.mem.eql(u8, try capture.span.slice(source), text))
        {
            return error.TestUnexpectedResult;
        }
    }
}
