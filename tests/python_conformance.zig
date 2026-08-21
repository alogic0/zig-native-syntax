const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.python.backend;

test "Python backend metadata is stable" {
    try std.testing.expectEqualStrings("python", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "Python scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'd', 'e', 'f', ' ', 0xff, '(', ')', ':' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/python/complete.py"),
            .required_scopes = &.{ .comment, .attribute, .keyword, .function, .type, .builtin, .variable, .string, .escape, .boolean, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "def broken(x:\n    return \"unterminated\\n<&>",
            .required_scopes = &.{ .keyword, .function, .variable, .string, .escape, .punctuation },
        },
        .multiline = .{
            .source = "text = \"\"\"first\nsecond <&>\"\"\"\n# done\n",
            .required_scopes = &.{ .variable, .string, .comment },
        },
        .escapable = .{
            .source = "value = \"<&>\\\"'\"",
            .required_scopes = &.{ .variable, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .punctuation },
        },
    });
}
