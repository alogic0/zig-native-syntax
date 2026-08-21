const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Proto backend conforms" {
    try h.expect(s.languages.proto.backend, @embedFile("corpus/proto/complete.proto"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .property }, "string x = \"<&>\\\"'\"; // comment");
}
