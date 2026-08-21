const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Gettext PO backend conforms" {
    try helper.expect(syntax.languages.po.backend, @embedFile("corpus/po/complete.txt"), &.{ .keyword, .string, .escape, .comment }, "value = \"<&>\\q'\" # comment");
}
