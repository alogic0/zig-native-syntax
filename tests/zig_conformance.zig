const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "Zig backend conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'c', 'o', 'n', 's', 't', ' ', 0xff, 'x' };

    try conformance.expectConforms(syntax.languages.zig.backend, .{
        .valid = .{
            .source = "const answer: u8 = 42;",
            .required_scopes = &.{ .keyword, .variable, .builtin, .type, .number },
        },
        .malformed = .{
            .source = "const before = 1; \\ invalid\nconst after = 2;",
            .required_scopes = &.{ .invalid, .variable },
        },
        .multiline = .{
            .source = "const first = 1;\n// comment\nconst second = \"two\";",
            .required_scopes = &.{ .comment, .string, .number },
        },
        .escapable = .{
            .source = "const text = \"<script>&'\\\"</script>\";",
            .required_scopes = &.{ .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.invalid},
        },
    });
}
