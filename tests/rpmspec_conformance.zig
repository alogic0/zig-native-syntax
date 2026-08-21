const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "RPM spec backend conforms" {
    try helper.expect(syntax.languages.rpmspec.backend, @embedFile("corpus/rpmspec/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
