const std = @import("std");
const s = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = s.languages.nasm.backend;

test "NASM backend conforms" {
    try std.testing.expectEqual(s.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(s.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/nasm/complete.nasm"), .required_scopes = &.{ .macro, .keyword, .type, .label, .string, .escape, .number, .comment, .operator } },
        .malformed = .{ .source = "%macro open 1\n  mov rax, 0x2a\n  db \"unterminated\\q<&>\n", .required_scopes = &.{ .macro, .number, .type, .string, .escape } },
        .multiline = .{ .source = "first:\n  call second\nsecond:\n  ret\n", .required_scopes = &.{ .label, .keyword } },
        .escapable = .{ .source = "msg: db \"<&>\\q'\" ; comment", .required_scopes = &.{ .label, .string, .escape, .comment } },
    });
}

test "NASM scanner classifies directives instructions registers macros and labels" {
    const source = @embedFile("corpus/nasm/complete.nasm");
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "%define", .macro);
    try expect(source, sink.captures(), "COUNT", .macro);
    try expect(source, sink.captures(), "section", .keyword);
    try expect(source, sink.captures(), "mov", .keyword);
    try expect(source, sink.captures(), "rax", .type);
    try expect(source, sink.captures(), "start", .label);
    try expect(source, sink.captures(), "render", .label);
    try expect(source, sink.captures(), ".done", .label);
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
