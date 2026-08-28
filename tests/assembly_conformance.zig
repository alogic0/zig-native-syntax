const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.assembly.backend;

test "Assembly backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/assembly/complete.s"), .required_scopes = &.{ .macro, .keyword, .type, .label, .string, .escape, .number, .comment } },
        .malformed = .{ .source = ".macro open arg\n  mov $0x2a, %rax\n  .ascii \"unterminated\\q<&>\n", .required_scopes = &.{ .macro, .number, .type, .string, .escape } },
        .multiline = .{ .source = "first:\n  call second\nsecond:\n  ret\n", .required_scopes = &.{ .label, .keyword } },
        .escapable = .{ .source = "msg: .ascii \"<&>\\q'\" # comment", .required_scopes = &.{ .label, .string, .escape, .comment } },
    });
}

test "Assembly scanner classifies directives instructions registers macros and labels" {
    const source = @embedFile("corpus/assembly/complete.s");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), ".macro", .macro);
    try expect(source, sink.captures(), "save", .macro);
    try expect(source, sink.captures(), ".section", .keyword);
    try expect(source, sink.captures(), "mov", .keyword);
    try expect(source, sink.captures(), "%rax", .type);
    try expect(source, sink.captures(), "start", .label);
    try expect(source, sink.captures(), "render", .label);
    try expect(source, sink.captures(), ".done", .label);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
