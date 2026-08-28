const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.agda.backend;

test "Agda backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/agda/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter, .property, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "module Broken where\ndata Open : Set where\n  make : Open\nrecord Missing : Set where\n  field value : Set\n", .required_scopes = &.{ .namespace, .type, .constructor, .property } },
        .multiline = .{ .source = "value : Set\nvalue input = input\n", .required_scopes = &.{ .function, .parameter, .type } },
        .escapable = .{ .source = "value = \"<&>\\q'\" -- comment", .required_scopes = &.{ .function, .string, .escape, .comment } },
    });
}

test "Agda parser classifies modules data records constructors fields and equations" {
    const source = @embedFile("corpus/agda/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "Demo.Core", .namespace);
    try expect(source, sink.captures(), "Data.Nat", .namespace);
    try expect(source, sink.captures(), "Item", .type);
    try expect(source, sink.captures(), "item", .constructor);
    try expect(source, sink.captures(), "Point", .type);
    try expect(source, sink.captures(), "x", .property);
    try expect(source, sink.captures(), "select", .function);
    try expect(source, sink.captures(), "value", .parameter);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
