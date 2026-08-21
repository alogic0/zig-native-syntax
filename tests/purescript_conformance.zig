const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "PureScript backend conforms" {
    try helper.expect(syntax.languages.purescript.backend, @embedFile("corpus/purescript/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" -- comment");
}
