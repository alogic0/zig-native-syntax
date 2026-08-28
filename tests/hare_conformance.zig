const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.hare.backend;

test "Hare backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/hare/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .constructor, .function, .parameter, .property, .variable, .constant, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "type open = struct { field: int,\nfn run(value: open) open = { return open { field = value.field;\n", .required_scopes = &.{ .keyword, .type, .property, .function, .parameter, .constructor } },
        .multiline = .{ .source = "use fmt;\nfn one(value: int) int = value;\n", .required_scopes = &.{ .namespace, .function, .parameter, .type } },
        .escapable = .{ .source = "let value: str = \"<&>\\q'\"; // comment", .required_scopes = &.{ .variable, .type, .string, .escape, .comment } },
    });
}

test "Hare parser classifies imports types fields functions declarations and constructors" {
    const source = @embedFile("corpus/hare/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "fmt", .namespace);
    try expect(source, sink.captures(), "io", .namespace);
    try expect(source, sink.captures(), "coords", .type);
    try expect(source, sink.captures(), "x", .property);
    try expect(source, sink.captures(), "y", .property);
    try expect(source, sink.captures(), "DEFAULT_LIMIT", .constant);
    try expect(source, sink.captures(), "global_count", .variable);
    try expect(source, sink.captures(), "translate", .function);
    try expect(source, sink.captures(), "point", .parameter);
    try expect(source, sink.captures(), "dx", .parameter);
    try expect(source, sink.captures(), "coords", .constructor);
    try expect(source, sink.captures(), "origin", .variable);
    try expect(source, sink.captures(), "printfln", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
