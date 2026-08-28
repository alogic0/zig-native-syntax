const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.uxntal.backend;

test "Uxntal backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/uxntal/complete.txt"), .required_scopes = &.{ .keyword, .label, .macro, .string, .number, .operator, .punctuation, .comment } },
        .malformed = .{ .source = "%broken { #1f INC2r\n( outer ( unterminated", .required_scopes = &.{ .macro, .number, .keyword, .comment } },
        .multiline = .{ .source = "@main\n  #2a DUPk\n  ?&main\n", .required_scopes = &.{ .label, .number, .keyword } },
        .escapable = .{ .source = "\"<&>' ( comment )", .required_scopes = &.{ .string, .comment } },
    });
}

test "Uxntal scanner classifies runes opcode modes macros and nested comments" {
    const source = @embedFile("corpus/uxntal/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "|0100", .number);
    try expect(source, sink.captures(), "%emit-byte", .macro);
    try expect(source, sink.captures(), "@main", .label);
    try expect(source, sink.captures(), "&loop", .label);
    try expect(source, sink.captures(), "#2a", .number);
    try expect(source, sink.captures(), "ADD2k", .keyword);
    try expect(source, sink.captures(), ",&loop", .label);
    try expect(source, sink.captures(), "$", .operator);
    try expect(source, sink.captures(), ";Screen/width", .label);
    try expect(source, sink.captures(), "DEI2", .keyword);
    try expect(source, sink.captures(), "\"hello", .string);
    try expect(source, sink.captures(), "( outer ( nested ) comment )", .comment);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
