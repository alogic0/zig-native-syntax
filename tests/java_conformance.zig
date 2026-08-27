const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Java backend conforms" {
    try std.testing.expectEqual(s.SupportLevel.verified_structural, s.languages.java.backend.info.support_level);
    try h.expect(s.languages.java.backend, @embedFile("corpus/java/complete.java"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .attribute, .function }, "String x = \"<&>\\\"'\"; // comment");
}
