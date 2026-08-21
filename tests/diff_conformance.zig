const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.diff.backend;

test "Diff backend metadata is stable" {
    try std.testing.expectEqualStrings("diff", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "Diff scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '+', 0xff, '\n', '-', 0xfe };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/diff/complete.diff"),
            .required_scopes = &.{ .keyword, .label, .special, .operator, .comment },
        },
        .malformed = .{
            .source = "@@ -1 +1\n+unterminated <&>",
            .required_scopes = &.{ .special, .operator },
        },
        .multiline = .{
            .source = " context\n-added\n+added\n",
            .required_scopes = &.{.operator},
        },
        .escapable = .{
            .source = "--- a/<old>&\n+++ b/\"new\"'\n",
            .required_scopes = &.{ .operator, .label },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.operator},
        },
    });
}
