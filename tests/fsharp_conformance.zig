const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "F# backend conforms" {
    try helper.expect(syntax.languages.fsharp.backend, @embedFile("corpus/fsharp/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
