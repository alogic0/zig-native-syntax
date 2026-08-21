const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Perl backend conforms" {
    try helper.expect(syntax.languages.perl.backend, @embedFile("corpus/perl/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
