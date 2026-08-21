const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Assembly backend conforms" {
    try h.expect(s.languages.assembly.backend, @embedFile("corpus/assembly/complete.s"), &.{ .keyword, .type, .string, .escape, .number, .comment, .label }, "msg: .ascii \"<&>\\\"'\" # comment");
}
