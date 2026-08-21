const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "SystemVerilog backend conforms" {
    try helper.expect(syntax.languages.systemverilog.backend, @embedFile("corpus/systemverilog/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
