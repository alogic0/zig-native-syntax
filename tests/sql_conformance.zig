const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.sql.backend;

test "SQL backend metadata is stable" {
    try std.testing.expectEqualStrings("sql", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "SQL scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'S', 'E', 'L', 'E', 'C', 'T', ' ', 0xff };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/sql/complete.sql"),
            .required_scopes = &.{ .comment, .keyword, .property, .variable, .function, .string, .escape, .boolean, .number, .parameter, .operator, .punctuation },
        },
        .malformed = .{
            .source = "SELECT /* open\n name FROM t WHERE value = 'unterminated <&>",
            .required_scopes = &.{ .keyword, .comment },
        },
        .multiline = .{
            .source = "SELECT $$first\nsecond <&>$$, count(*)\nFROM items;\n",
            .required_scopes = &.{ .keyword, .string, .function, .operator },
        },
        .escapable = .{
            .source = "SELECT '<&>''\\n\"' AS value;",
            .required_scopes = &.{ .keyword, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.keyword},
        },
    });
}
