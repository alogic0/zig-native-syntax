const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.starlark.backend;

test "Starlark declarations, parameters, and rule attributes are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "def build(name, srcs = []):\n    native.genrule(name = name, srcs = srcs)";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "build", .function);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "genrule", .property);
    try expect(source, sink.captures(), "srcs", .property);
}

test "Starlark backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/starlark/complete.bzl"), .required_scopes = &.{ .keyword, .function, .parameter, .property, .variable, .string, .punctuation } },
        .malformed = .{ .source = "def open(name, srcs = [\"unterminated<&>\n", .required_scopes = &.{ .keyword, .function, .parameter, .string } },
        .multiline = .{ .source = "def first(value):\n    return value\ndef second(other):\n    return other\n", .required_scopes = &.{ .keyword, .function, .parameter, .variable } },
        .escapable = .{ .source = "value = \"<&>\\\"'\" # comment", .required_scopes = &.{ .property, .string, .escape, .comment } },
    });
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
