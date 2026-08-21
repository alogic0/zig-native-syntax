const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Common Lisp backend conforms" {
    try helper.expect(syntax.languages.commonlisp.backend, @embedFile("corpus/commonlisp/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" ; comment");
}
