const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "E-mail backend conforms" {
    try helper.expect(syntax.languages.mail.backend, @embedFile("corpus/mail/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" > comment");
}
