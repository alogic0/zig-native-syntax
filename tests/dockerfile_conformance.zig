const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.dockerfile.backend;

test "Dockerfile backend metadata is stable" {
    try std.testing.expectEqualStrings("dockerfile", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
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
