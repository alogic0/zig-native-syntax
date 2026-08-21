const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "LLVM IR backend conforms" {
    try helper.expect(syntax.languages.llvm.backend, @embedFile("corpus/llvm/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" ; comment");
}
