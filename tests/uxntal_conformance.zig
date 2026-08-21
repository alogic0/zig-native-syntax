const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");

test "Uxntal backend conforms" {
    try helper.expect(syntax.languages.uxntal.backend, @embedFile("corpus/uxntal/complete.txt"), &.{ .keyword, .string, .escape, .number, .comment }, "value = \"<&>\\q'\" ( comment )");
}
