const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.dockerfile.backend;

test "Dockerfile backend metadata is stable" {
    try std.testing.expectEqualStrings("dockerfile", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
}

test "Dockerfile scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'R', 'U', 'N', ' ', 0xff };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/dockerfile/complete.Dockerfile"),
            .required_scopes = &.{ .special, .keyword, .attribute, .variable, .string, .escape, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "FROM alpine AS\nRUN echo \"unterminated ${NAME} <&>",
            .required_scopes = &.{ .keyword, .string, .variable },
        },
        .multiline = .{
            .source = "# comment\nRUN echo one \\\n  && echo two\n",
            .required_scopes = &.{ .comment, .keyword, .escape, .operator },
        },
        .escapable = .{
            .source = "RUN printf '%s' \"<&>\\\"'\"",
            .required_scopes = &.{ .keyword, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.keyword},
        },
    });
}

test "Dockerfile composes shell and JSON instruction forms" {
    const source =
        \\RUN --mount=type=cache,target=/root/.cache printf '%s' "$HOME"
        \\CMD ["/bin/app", "--serve"]
        \\RUN <<'EOF'
        \\echo "$HOME"
        \\EOF
        \\FROM alpine
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "RUN", .keyword);
    try expectCapture(source, sink.captures(), "--mount=type=cache,target=/root/.cache", .attribute);
    try expectCapture(source, sink.captures(), "printf", .function);
    try expectCapture(source, sink.captures(), "$HOME", .variable);
    try expectCapture(source, sink.captures(), "[\"/bin/app\", \"--serve\"]", .embedded);
    try expectCapture(source, sink.captures(), "\"/bin/app\"", .string);
    try expectCapture(source, sink.captures(), "echo", .function);
    try expectCapture(source, sink.captures(), "EOF", .label);
    try expectCapture(source, sink.captures(), "FROM", .keyword);
}

test "Dockerfile representative BuildKit corpus preserves nested roles" {
    const source = @embedFile("corpus/dockerfile/buildkit.Dockerfile");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "# syntax=docker/dockerfile:1.7", .special);
    try expectCapture(source, sink.captures(), "--mount=type=cache,target=/root/.cache", .attribute);
    try expectCapture(source, sink.captures(), "zig", .function);
    try expectCapture(source, sink.captures(), "[\"./server\", \"--port\", \"8080\"]", .embedded);
}

fn expectCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
