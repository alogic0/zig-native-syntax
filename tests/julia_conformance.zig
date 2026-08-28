const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.julia.backend;

test "Julia backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/julia/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .namespace, .type, .function, .parameter, .macro, .constant } },
        .malformed = .{ .source = "module Broken\nfunction run(value::Thing\n text = \"unterminated\n#= open comment", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .type, .string, .comment } },
        .multiline = .{ .source = "module First\nend\nmodule Second\nend\n", .required_scopes = &.{ .keyword, .namespace } },
        .escapable = .{ .source = "function run(value)\n \"<&>\\q'\" # comment\nend", .required_scopes = &.{ .keyword, .function, .parameter, .string, .escape, .comment } },
    });
}

test "Julia parser classifies declarations macros and symbols" {
    const source = @embedFile("corpus/julia/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "Geometry", .namespace);
    try expect(source, sink.captures(), "Shape", .type);
    try expect(source, sink.captures(), "Circle", .type);
    try expect(source, sink.captures(), "area", .function);
    try expect(source, sink.captures(), "circle", .parameter);
    try expect(source, sink.captures(), "scale", .parameter);
    try expect(source, sink.captures(), "@assert", .macro);
    try expect(source, sink.captures(), "checked", .macro);
    try expect(source, sink.captures(), ":ok", .constant);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
