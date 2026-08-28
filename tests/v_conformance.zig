const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.v.backend;

test "V backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/v/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter, .property, .variable, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "module broken\nstruct Open {\n field string\nfn run(value int {\n", .required_scopes = &.{ .keyword, .namespace, .type, .property, .function, .parameter } },
        .multiline = .{ .source = "module demo\nfn one(value int) int { return value }\n", .required_scopes = &.{ .namespace, .function, .parameter } },
        .escapable = .{ .source = "value := \"<&>\\q'\" // comment", .required_scopes = &.{ .variable, .string, .escape, .comment } },
    });
}

test "V parser classifies modules structs methods fields and short declarations" {
    const source = @embedFile("corpus/v/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "main", .namespace);
    try expect(source, sink.captures(), "time", .namespace);
    try expect(source, sink.captures(), "Item", .type);
    try expect(source, sink.captures(), "value", .property);
    try expect(source, sink.captures(), "total", .function);
    try expect(source, sink.captures(), "item", .parameter);
    try expect(source, sink.captures(), "delta", .parameter);
    try expect(source, sink.captures(), "make_item", .function);
    try expect(source, sink.captures(), "Item", .constructor);
    try expect(source, sink.captures(), "item", .variable);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
