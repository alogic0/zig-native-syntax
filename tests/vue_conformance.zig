const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
test "Vue backend conforms" {
    try c.expectConforms(s.languages.vue.backend, .{ .valid = .{ .source = @embedFile("corpus/vue/complete.vue"), .required_scopes = &.{ .tag, .attribute, .string, .embedded, .comment, .punctuation } }, .malformed = .{ .source = "<template><div title=\"unterminated<&>\n", .required_scopes = &.{ .tag, .attribute, .string } }, .multiline = .{ .source = "<template>\n<p>{{ value }}<&></p>\n", .required_scopes = &.{ .tag, .embedded } }, .escapable = .{ .source = "<!-- <&>\"' -->", .required_scopes = &.{.comment} } });
}
