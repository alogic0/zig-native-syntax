const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.toml.backend;

test "TOML backend metadata is stable" {
    try std.testing.expectEqualStrings("toml", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "TOML scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'x', ' ', '=', ' ', '"', 0xff, '"' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/toml/complete.toml"),
            .required_scopes = &.{ .property, .namespace, .string, .escape, .boolean, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "[package\nvalue = \"unterminated\\u12<&>",
            .required_scopes = &.{ .namespace, .property, .string, .escape, .operator, .punctuation },
        },
        .multiline = .{
            .source = "text = \"\"\"first\nsecond\"\"\"\n# comment\n",
            .required_scopes = &.{ .property, .string, .comment },
        },
        .escapable = .{
            .source = "html = \"<&>\\\"'\"",
            .required_scopes = &.{ .property, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .property, .string, .operator },
        },
    });
}
