const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Kotlin backend conforms" {
    try h.expect(s.languages.kotlin.backend, @embedFile("corpus/kotlin/complete.kt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .attribute, .function }, "val x = \"<&>\\\"'\" // comment");
}
