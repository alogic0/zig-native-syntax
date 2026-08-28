const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.tablegen.backend;

test "TableGen metadata and declarations are stable" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "class Operand<string name>; def ADD : Operand<\"add\"> { let Pattern = !if(true, $lhs, $rhs); }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "Operand", .type);
    try expectCapture(source, sink.captures(), "ADD", .constant);
    try expectCapture(source, sink.captures(), "Pattern", .property);
    try expectCapture(source, sink.captures(), "!if", .builtin);
    try expectCapture(source, sink.captures(), "$lhs", .variable);
}

test "TableGen backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/tablegen/complete.td"), .required_scopes = &.{ .keyword, .type, .constant, .property, .variable, .string, .number, .comment, .embedded, .operator, .punctuation } },
        .malformed = .{ .source = "def OPEN : Base<\"unterminated<&>\nlet Value = [{ open", .required_scopes = &.{ .keyword, .constant, .type, .string, .embedded } },
        .multiline = .{ .source = "class Base<int n>;\ndef Item : Base<1>;\n", .required_scopes = &.{ .keyword, .type, .constant, .number } },
        .escapable = .{ .source = "def X { string S = \"<&>\\\"'\"; // comment\n}", .required_scopes = &.{ .keyword, .constant, .type, .string, .escape, .comment } },
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
