const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.c.backend;

test "C backend metadata is stable" {
    try std.testing.expectEqualStrings("c", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "C scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'i', 'n', 't', ' ', 0xff, ';' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/c/complete.c"),
            .required_scopes = &.{ .macro, .comment, .documentation, .keyword, .builtin, .type, .function, .variable, .string, .escape, .constant, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "#define OPEN(x) \\\n  ((x) + 1\nint main( { return \"unterminated\\n<&>",
            .required_scopes = &.{ .macro, .builtin, .function, .keyword, .string, .escape },
        },
        .multiline = .{
            .source = "/* open\n comment <&> */\nint done(void) { return 0; }\n",
            .required_scopes = &.{ .comment, .builtin, .function, .keyword, .number },
        },
        .escapable = .{
            .source = "const char *s = \"<&>\\\"'\";",
            .required_scopes = &.{ .keyword, .builtin, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .builtin, .punctuation },
        },
    });
}
