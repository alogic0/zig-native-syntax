const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "LaTeX backend conforms" {
    try helper.expect(syntax.languages.latex.backend, @embedFile("corpus/latex/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" % comment");
}
