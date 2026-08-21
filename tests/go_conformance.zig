const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Go backend conforms" {
    try h.expect(s.languages.go.backend, @embedFile("corpus/go/complete.go"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function }, "var x = \"<&>\\\"'\" // comment");
}
