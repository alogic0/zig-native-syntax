const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "comment-tag backend conforms" {
    try conformance.expectConforms(syntax.languages.comment.backend, .{
        .valid = .{
            .source = @embedFile("corpus/comment/complete.txt"),
            .required_scopes = &.{ .special, .constant, .punctuation, .number, .string, .markup_link },
        },
        .malformed = .{
            .source = "FIXME(unclosed <&>",
            .required_scopes = &.{ .special, .constant, .punctuation },
        },
        .multiline = .{
            .source = "NOTE: first\nBUG: second\n",
            .required_scopes = &.{ .special, .punctuation },
        },
        .escapable = .{
            .source = "TODO: preserve <unsafe>& \"' at https://example.test",
            .required_scopes = &.{ .special, .string, .markup_link },
        },
        .extra_cases = &.{
            .{ .source = "plain comment text", .required_scopes = &.{} },
            .{ .source = "WIP(user): issue #42", .required_scopes = &.{ .special, .constant, .number } },
        },
    });
}
