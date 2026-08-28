const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Kotlin backend conforms" {
    try std.testing.expectEqual(s.SupportLevel.verified_structural, s.languages.kotlin.backend.info.support_level);
    try h.expect(s.languages.kotlin.backend, @embedFile("corpus/kotlin/complete.kt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .attribute, .function }, "val x = \"<&>\\\"'\" // comment");
}
