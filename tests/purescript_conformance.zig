const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.purescript.backend;

test "PureScript backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/purescript/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter, .property, .variable, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "module Broken where\ndata Open = Ready | Failed String\nrender value = { name: value\n", .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter } },
        .multiline = .{ .source = "module Demo where\none :: Int -> Int\none value = value\n", .required_scopes = &.{ .namespace, .function, .type, .parameter } },
        .escapable = .{ .source = "value = \"<&>\\q'\" -- comment", .required_scopes = &.{ .function, .string, .escape, .comment } },
    });
}

test "PureScript scanner classifies modules types functions records and constructors" {
    const source = @embedFile("corpus/purescript/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "Demo.Profile", .namespace);
    try expect(source, sink.captures(), "Profile", .type);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "Status", .type);
    try expect(source, sink.captures(), "Ready", .constructor);
    try expect(source, sink.captures(), "User", .constructor);
    try expect(source, sink.captures(), "render", .function);
    try expect(source, sink.captures(), "profile", .parameter);
    try expect(source, sink.captures(), "M", .namespace);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
