const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "NASM backend conforms" {
    try h.expect(s.languages.nasm.backend, @embedFile("corpus/nasm/complete.nasm"), &.{ .keyword, .type, .string, .escape, .number, .comment, .label }, "msg: db \"<&>\\\"'\" ; comment");
}
