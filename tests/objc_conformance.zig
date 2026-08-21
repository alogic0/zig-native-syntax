const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Objective-C backend conforms" {
    try h.expect(s.languages.objc.backend, @embedFile("corpus/objc/complete.m"), &.{ .macro, .keyword, .type, .string, .escape, .number, .boolean, .comment, .attribute, .function }, "id x = \"<&>\\\"'\"; // comment");
}
