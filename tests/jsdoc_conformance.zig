const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
test "JSDoc backend conforms" {
    try c.expectConforms(s.languages.jsdoc.backend, .{ .valid = .{ .source = @embedFile("corpus/jsdoc/complete.jsdoc"), .required_scopes = &.{ .comment, .documentation, .attribute, .type, .markup_code } }, .malformed = .{ .source = "/** @param {string value <&>", .required_scopes = &.{ .comment, .documentation, .attribute, .type } }, .multiline = .{ .source = "/**\n * @returns {string}\n", .required_scopes = &.{ .comment, .documentation, .attribute, .type } }, .escapable = .{ .source = "/** <&>\"' `code` */", .required_scopes = &.{ .comment, .markup_code } } });
}
