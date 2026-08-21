const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "PHP backend conforms" {
    try h.expect(s.languages.php.backend, @embedFile("corpus/php/complete.php"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .variable }, "$x = \"<&>\\\"'\"; // comment");
}
