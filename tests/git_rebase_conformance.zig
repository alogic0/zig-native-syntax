const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Git rebase backend conforms" {
    try helper.expect(syntax.languages.git_rebase.backend, @embedFile("corpus/git_rebase/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
