const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Nim backend conforms" {
    try helper.expect(syntax.languages.nim.backend, @embedFile("corpus/nim/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
