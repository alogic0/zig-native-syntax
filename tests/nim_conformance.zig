const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.nim.backend;

test "Nim backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/nim/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter, .property, .variable, .constant, .attribute, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "type\n  Open* = object\n    field*: string\nproc run*(value: Open\n  #[ nested #[ comment ]#\n", .required_scopes = &.{ .keyword, .type, .property, .function, .parameter, .comment } },
        .multiline = .{ .source = "proc one(value: int): int = value\nproc two(other: int): int = other\n", .required_scopes = &.{ .keyword, .function, .parameter, .type } },
        .escapable = .{ .source = "let value = \"<&>\\q'\" # comment", .required_scopes = &.{ .keyword, .variable, .string, .escape, .comment } },
    });
}

test "Nim parser classifies imports declarations fields procedures and pragmas" {
    const source = @embedFile("corpus/nim/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "std", .namespace);
    try expect(source, sink.captures(), "strformat", .namespace);
    try expect(source, sink.captures(), "Person", .type);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "Limit", .constant);
    try expect(source, sink.captures(), "render", .function);
    try expect(source, sink.captures(), "person", .parameter);
    try expect(source, sink.captures(), "Person", .constructor);
    try expect(source, sink.captures(), "{.inline.}", .attribute);
    try expect(source, sink.captures(), "message", .variable);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
