const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Gleam backend conforms" {
    try helper.expect(syntax.languages.gleam.backend, @embedFile("corpus/gleam/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
