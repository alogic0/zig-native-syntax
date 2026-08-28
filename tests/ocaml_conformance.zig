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

test "OCaml fused scanner preserves rendered output" {
    const source = "module Demo = struct\nlet rec map f input : int = f input\ntype shape = Circle of float\nend";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(source, sink.captures(), std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "<span class=\"syntax-keyword\">module</span> <span class=\"syntax-namespace\">Demo</span> <span class=\"syntax-operator\">=</span> <span class=\"syntax-keyword\">struct</span>\n" ++
            "<span class=\"syntax-keyword\">let</span> <span class=\"syntax-keyword\">rec</span> <span class=\"syntax-function\">map</span> <span class=\"syntax-parameter\">f</span> <span class=\"syntax-parameter\">input</span> <span class=\"syntax-operator\">:</span> <span class=\"syntax-builtin syntax-type\">int</span> <span class=\"syntax-operator\">=</span> <span class=\"syntax-variable\">f</span> <span class=\"syntax-variable\">input</span>\n" ++
            "<span class=\"syntax-keyword\">type</span> <span class=\"syntax-type\">shape</span> <span class=\"syntax-operator\">=</span> <span class=\"syntax-constructor\">Circle</span> <span class=\"syntax-keyword\">of</span> <span class=\"syntax-builtin syntax-type\">float</span>\n" ++
            "<span class=\"syntax-keyword\">end</span>",
        output.written(),
    );
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
