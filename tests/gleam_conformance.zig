const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.gleam.backend;

test "Gleam backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.experimental, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/gleam/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .documentation, .attribute, .namespace, .type, .constructor, .function, .parameter, .property, .constant } },
        .malformed = .{ .source = "pub fn broken(value: String) { \"unterminated\\u12\n", .required_scopes = &.{ .keyword, .function, .parameter, .type, .string, .escape } },
        .multiline = .{ .source = "import gleam/list\npub fn first() { Person() }\npub fn second() { True }\n", .required_scopes = &.{ .namespace, .function, .constructor } },
        .escapable = .{ .source = "let value = \"<&>\\q'\" // comment", .required_scopes = &.{ .keyword, .variable, .string, .escape, .comment } },
    });
}

test "Gleam parser classifies declarations imports parameters and fields" {
    const source = @embedFile("corpus/gleam/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "gleam/list", .namespace);
    try expect(source, sink.captures(), "Person", .type);
    try expect(source, sink.captures(), "Person", .constructor);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "person", .parameter);
    try expect(source, sink.captures(), "prefix", .constant);
    try expect(source, sink.captures(), "@external", .attribute);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
