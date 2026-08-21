const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Elixir backend conforms" {
    try helper.expect(syntax.languages.elixir.backend, @embedFile("corpus/elixir/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
