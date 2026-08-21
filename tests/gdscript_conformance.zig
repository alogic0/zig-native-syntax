const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "GDScript backend conforms" {
    try helper.expect(syntax.languages.gdscript.backend, @embedFile("corpus/gdscript/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
