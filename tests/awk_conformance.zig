const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "AWK backend conforms" {
    try helper.expect(syntax.languages.awk.backend, @embedFile("corpus/awk/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
