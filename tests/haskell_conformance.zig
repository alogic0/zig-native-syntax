const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Haskell backend conforms" {
    try helper.expect(syntax.languages.haskell.backend, @embedFile("corpus/haskell/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" -- comment");
}
