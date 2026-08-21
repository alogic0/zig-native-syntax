const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "C++ backend conforms" {
    try h.expect(s.languages.cpp.backend, @embedFile("corpus/cpp/complete.cpp"), &.{ .macro, .keyword, .type, .string, .escape, .number, .boolean, .comment, .function }, "const char* x = \"<&>\\\"'\"; // comment");
}
