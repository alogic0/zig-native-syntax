const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "C# backend conforms" {
    try std.testing.expectEqual(s.SupportLevel.verified_structural, s.languages.c_sharp.backend.info.support_level);
    try h.expect(s.languages.c_sharp.backend, @embedFile("corpus/c_sharp/complete.cs"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function }, "string x = \"<&>\\\"'\"; // comment");
}
