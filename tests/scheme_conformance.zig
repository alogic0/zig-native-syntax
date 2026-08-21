const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Scheme backend conforms" {
    try helper.expect(syntax.languages.scheme.backend, @embedFile("corpus/scheme/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" ; comment");
}
