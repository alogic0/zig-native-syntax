const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.d.backend;

test "D backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/d/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter, .property, .variable, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "module broken.name;\nstruct Open { int field;\nint run(int value { return value;\n", .required_scopes = &.{ .keyword, .namespace, .type, .property, .function, .parameter } },
        .multiline = .{ .source = "module first.second;\nint one(int value) { return value; }\n", .required_scopes = &.{ .namespace, .function, .parameter } },
        .escapable = .{ .source = "string value = \"<&>\\q'\"; // comment", .required_scopes = &.{ .type, .variable, .string, .escape, .comment } },
    });
}

test "D parser classifies modules aggregates fields functions and calls" {
    const source = @embedFile("corpus/d/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "demo", .namespace);
    try expect(source, sink.captures(), "render", .namespace);
    try expect(source, sink.captures(), "Item", .type);
    try expect(source, sink.captures(), "value", .property);
    try expect(source, sink.captures(), "total", .function);
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
