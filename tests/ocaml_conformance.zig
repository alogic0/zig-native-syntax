const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.ocaml.backend;

test "OCaml backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/ocaml/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .attribute, .namespace, .type, .constructor, .function, .parameter, .property } },
        .malformed = .{ .source = "module Broken = struct\n  let rec run value = (* outer (* nested\n  let text = \"unterminated\n", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .comment } },
        .multiline = .{ .source = "module First = struct end\nmodule Second = struct end\n", .required_scopes = &.{ .keyword, .namespace } },
        .escapable = .{ .source = "let run value = \"<&>\\q'\" (* comment *)", .required_scopes = &.{ .keyword, .function, .parameter, .string, .escape, .comment } },
    });
}

test "OCaml parser classifies modules declarations patterns and fields" {
    const source = @embedFile("corpus/ocaml/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "[@@@warning \"-32\"]", .attribute);
    try expect(source, sink.captures(), "Geometry", .namespace);
    try expect(source, sink.captures(), "Stdlib.List", .namespace);
    try expect(source, sink.captures(), "measured", .type);
    try expect(source, sink.captures(), "'a", .type);
    try expect(source, sink.captures(), "Circle", .constructor);
    try expect(source, sink.captures(), "radius", .property);
    try expect(source, sink.captures(), "area", .function);
    try expect(source, sink.captures(), "map_option", .function);
    try expect(source, sink.captures(), "f", .parameter);
    try expect(source, sink.captures(), "input", .parameter);
    try expect(source, sink.captures(), "~factor", .parameter);
    try expect(source, sink.captures(), "shape", .parameter);
    try expect(source, sink.captures(), "find", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
