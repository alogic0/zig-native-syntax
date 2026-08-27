const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.mlir.backend;

test "MLIR metadata and sigil roles are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "func.func @run(%arg: !dialect.type) { %0 = custom.op %arg : i32\n cf.br ^done }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "@run", .function);
    try expectCapture(source, sink.captures(), "%arg", .variable);
    try expectCapture(source, sink.captures(), "!dialect.type", .type);
    try expectCapture(source, sink.captures(), "^done", .label);
}

test "MLIR backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/mlir/complete.mlir"), .required_scopes = &.{ .comment, .keyword, .function, .variable, .label, .type, .string, .number, .operator, .punctuation } },
        .malformed = .{ .source = "func.func @open(%arg: tensor<4xf32> { %0 = \"unterminated<&>\n", .required_scopes = &.{ .function, .variable, .type, .string } },
        .multiline = .{ .source = "%0 = arith.constant 1 : i32\nreturn %0 : i32\n", .required_scopes = &.{ .variable, .function, .keyword, .number, .type } },
        .escapable = .{ .source = "%0 = custom.op \"<&>\\\"'\" // comment", .required_scopes = &.{ .variable, .function, .string, .escape, .comment } },
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
