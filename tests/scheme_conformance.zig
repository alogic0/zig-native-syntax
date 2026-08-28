const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.scheme.backend;

test "Scheme backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/scheme/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .function, .macro, .parameter, .property, .variable, .constant, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "(define-library (broken core)\n(define (open value\n  #| nested #| comment |#\n", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .comment } },
        .multiline = .{ .source = "(define (one value) value)\n(define (two other) other)\n", .required_scopes = &.{ .keyword, .function, .parameter } },
        .escapable = .{ .source = "(define (run value) \"<&>\\q'\") ; comment", .required_scopes = &.{ .function, .parameter, .string, .escape, .comment } },
    });
}

test "Scheme scanner classifies libraries procedures records macros and bindings" {
    const source = @embedFile("corpus/scheme/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "demo", .namespace);
    try expect(source, sink.captures(), "core", .namespace);
    try expect(source, sink.captures(), "<person>", .type);
    try expect(source, sink.captures(), "make-person", .function);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "person", .parameter);
    try expect(source, sink.captures(), "message", .variable);
    try expect(source, sink.captures(), "missing", .constant);
    try expect(source, sink.captures(), "when-ready", .macro);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
