const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Assembly backend conforms" {
    try std.testing.expectEqual(s.SupportLevel.verified_lexical, s.languages.assembly.backend.info.support_level);
    try h.expect(s.languages.assembly.backend, @embedFile("corpus/assembly/complete.s"), &.{ .keyword, .type, .string, .escape, .number, .comment, .label }, "msg: .ascii \"<&>\\\"'\" # comment");
}
