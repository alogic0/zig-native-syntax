const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
test "Astro backend conforms" {
    try c.expectConforms(s.languages.astro.backend, .{ .valid = .{ .source = @embedFile("corpus/astro/complete.astro"), .required_scopes = &.{ .special, .embedded, .tag, .attribute, .string, .comment, .punctuation } }, .malformed = .{ .source = "---\nconst x = '<&>'\n<div title=\"open\n", .required_scopes = &.{ .special, .embedded } }, .multiline = .{ .source = "---\nconst x = 1\n---\n<div><&></div>\n", .required_scopes = &.{ .special, .embedded, .tag } }, .escapable = .{ .source = "<!-- <&>\"' -->", .required_scopes = &.{.comment} } });
}
