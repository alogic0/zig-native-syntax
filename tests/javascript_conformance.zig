const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.javascript.backend;

test "JavaScript backend metadata is stable" {
    try std.testing.expectEqualStrings("javascript", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "JavaScript scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'c', 'o', 'n', 's', 't', ' ', 0xff, '=', '1', ';' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/javascript/complete.js"),
            .required_scopes = &.{ .comment, .documentation, .keyword, .type, .function, .property, .builtin, .variable, .string, .escape, .boolean, .constant, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "function broken(value { return `unfinished ${value}\\n<&>",
            .required_scopes = &.{ .keyword, .function, .variable, .string, .escape, .punctuation },
        },
        .multiline = .{
            .source = "/* open\ncomment <&> */\nconst text = `first\nsecond`;\n",
            .required_scopes = &.{ .comment, .keyword, .variable, .string },
        },
        .escapable = .{
            .source = "const value = \"<&>\\\"'\";",
            .required_scopes = &.{ .keyword, .variable, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .number, .operator, .punctuation },
        },
    });
}
