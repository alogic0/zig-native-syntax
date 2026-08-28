const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "LLVM IR backend conforms" {
    const backend = syntax.languages.llvm.backend;
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/llvm/complete.txt"), .required_scopes = &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .variable, .constant, .label } },
        .malformed = .{ .source = "define i32 @open(%value { ret i32 0 ; <&>\n", .required_scopes = &.{ .keyword, .type, .function, .variable, .number, .comment } },
        .multiline = .{ .source = "entry:\n  %sum = add i32 1, 2\n", .required_scopes = &.{ .label, .variable, .keyword, .type, .number } },
        .escapable = .{ .source = "@text = constant [3 x i8] c\"<&>\\0A'\" ; comment", .required_scopes = &.{ .constant, .type, .string, .escape, .comment } },
    });
}
