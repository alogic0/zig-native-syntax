const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "OpenSCAD backend conforms" {
    try helper.expect(syntax.languages.openscad.backend, @embedFile("corpus/openscad/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
