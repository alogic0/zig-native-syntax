const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Elm backend conforms" {
    try helper.expect(syntax.languages.elm.backend, @embedFile("corpus/elm/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" -- comment");
}
