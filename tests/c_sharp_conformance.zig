const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "C# backend conforms" {
    try h.expect(s.languages.c_sharp.backend, @embedFile("corpus/c_sharp/complete.cs"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function }, "string x = \"<&>\\\"'\"; // comment");
}
