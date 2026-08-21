const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
test "Regex backend conforms" {
    try c.expectConforms(s.languages.regex.backend, .{ .valid = .{ .source = @embedFile("corpus/regex/complete.regex"), .required_scopes = &.{ .escape, .string, .operator, .special, .punctuation } }, .malformed = .{ .source = "^(unterminated[<&>\\d+", .required_scopes = &.{ .special, .punctuation, .string } }, .multiline = .{ .source = "^first$\n^second$", .required_scopes = &.{.special} }, .escapable = .{ .source = "[<&>\"']\\w+", .required_scopes = &.{ .string, .escape, .operator } } });
}
