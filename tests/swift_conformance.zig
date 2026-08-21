const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Swift backend conforms" {
    try h.expect(s.languages.swift.backend, @embedFile("corpus/swift/complete.swift"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .attribute, .function }, "let x = \"<&>\\\"'\" // comment");
}
