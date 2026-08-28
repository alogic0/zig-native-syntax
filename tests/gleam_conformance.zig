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

test "Gleam parser classifies structural language forms" {
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
    try expect(source, sink.captures(), "text", .namespace);
    try expect(source, sink.captures(), "name", .variable);
    try expect(source, sink.captures(), "enabled", .variable);
    try expect(source, sink.captures(), "suffix", .parameter);
    try expect(source, sink.captures(), "updated", .variable);
    try expect(source, sink.captures(), "enabled", .property);
    try expect(source, sink.captures(), "try", .function);
    try expect(source, sink.captures(), "append", .function);
    try expect(source, sink.captures(), "size", .attribute);
    try expect(source, sink.captures(), "utf8", .attribute);
    try expectCount(source, sink.captures(), "list", .namespace, 1);
    try expectCount(source, sink.captures(), "result", .namespace, 1);
    try expectCount(source, sink.captures(), "text", .namespace, 3);
    try expectWithin(source, sink.captures(), "Person(..person", "person", .variable);
    try expectWithin(source, sink.captures(), "enabled: False", "enabled", .property);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectCount(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope, minimum: usize) !void {
    var count: usize = 0;
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) count += 1;
    }
    try std.testing.expect(count >= minimum);
}

fn expectWithin(source: []const u8, captures: []const syntax.Capture, context: []const u8, text: []const u8, scope: syntax.Scope) !void {
    const context_start = std.mem.indexOf(u8, source, context) orelse return error.TestExpectedEqual;
    const relative_start = std.mem.indexOf(u8, context, text) orelse return error.TestExpectedEqual;
    const start = context_start + relative_start;
    for (captures) |capture| {
        if (capture.scope == scope and capture.span.start == start and capture.span.end == start + text.len) return;
    }
    return error.TestExpectedEqual;
}
