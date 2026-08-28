const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.nickel.backend;
test "Nickel backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/nickel/complete.txt"), .required_scopes = &.{ .keyword, .type, .function, .parameter, .property, .variable, .namespace, .embedded, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "let make = fun value => { field | String = \"unterminated %{value\n", .required_scopes = &.{ .function, .parameter, .property, .type, .string } },
        .multiline = .{ .source = "let make = fun value => value in\nstd.string.uppercase (make \"x\")\n", .required_scopes = &.{ .function, .parameter, .namespace, .property } },
        .escapable = .{ .source = "let value = \"<&>\\q'\" in value # comment", .required_scopes = &.{ .variable, .string, .escape, .comment } },
    });
}

test "Nickel parser classifies functions parameters records bindings and interpolation" {
    const source = @embedFile("corpus/nickel/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "make_item", .function);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "enabled", .parameter);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "nested", .namespace);
    try expect(source, sink.captures(), "count", .property);
    try expect(source, sink.captures(), "%{name}", .embedded);
    try expect(source, sink.captures(), "item", .variable);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
