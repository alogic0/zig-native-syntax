const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.pdll.backend;

test "PDLL declarations and parameters are structural" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "Rewrite convert(value: Value) -> Value; Pattern Demo { let root: Op; erase root; }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "convert", .function);
    try expect(source, sink.captures(), "value", .parameter);
    try expect(source, sink.captures(), "Demo", .function);
    try expect(source, sink.captures(), "root", .variable);
}

test "PDLL backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/pdll/complete.pdll"), .required_scopes = &.{ .keyword, .type, .function, .parameter, .variable, .comment, .operator, .punctuation } },
        .malformed = .{ .source = "Pattern Open { let root: Op<dialect.op; rewrite root <&>\n", .required_scopes = &.{ .keyword, .function, .variable, .type } },
        .multiline = .{ .source = "Rewrite first(value: Value);\nRewrite second(type: Type);\n", .required_scopes = &.{ .keyword, .function, .parameter, .type } },
        .escapable = .{ .source = "include \"<&>\\\"'\"; // comment", .required_scopes = &.{ .keyword, .string, .escape, .comment } },
    });
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
