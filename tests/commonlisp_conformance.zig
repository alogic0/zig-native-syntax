const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.commonlisp.backend;

test "Common Lisp backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/commonlisp/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .function, .macro, .parameter, .property, .variable, .constant, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "(defpackage #:broken\n(defun open (value\n  #| nested #| comment |#\n", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .comment } },
        .multiline = .{ .source = "(defun one (value) value)\n(defun two (other) other)\n", .required_scopes = &.{ .keyword, .function, .parameter } },
        .escapable = .{ .source = "(defun run (value) \"<&>\\q'\") ; comment", .required_scopes = &.{ .function, .parameter, .string, .escape, .comment } },
    });
}

test "Common Lisp scanner classifies definitions parameters slots and bindings" {
    const source = @embedFile("corpus/commonlisp/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "#:demo", .namespace);
    try expect(source, sink.captures(), "person", .type);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "+limit+", .constant);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "person", .parameter);
    try expect(source, sink.captures(), "prefix", .parameter);
    try expect(source, sink.captures(), "with-person", .macro);
    try expect(source, sink.captures(), "message", .variable);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
