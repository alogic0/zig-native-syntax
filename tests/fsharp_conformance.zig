const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.fsharp.backend;

test "F# backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/fsharp/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .macro, .attribute, .namespace, .type, .constructor, .function, .parameter, .property } },
        .malformed = .{ .source = "namespace Broken\nlet rec run value = (* outer (* nested\nlet text = \"\"\"unterminated\n", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .comment } },
        .multiline = .{ .source = "namespace First\nmodule One = struct end\nnamespace Second\n", .required_scopes = &.{ .keyword, .namespace } },
        .escapable = .{ .source = "let run value = \"<&>\\q'\" // comment", .required_scopes = &.{ .keyword, .function, .parameter, .string, .escape, .comment } },
    });
}

test "F# parser classifies namespaces declarations unions and members" {
    const source = @embedFile("corpus/fsharp/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "#r \"nuget: Example, 1.0.0\"", .macro);
    try expect(source, sink.captures(), "Demo.Geometry", .namespace);
    try expect(source, sink.captures(), "System.Collections.Generic", .namespace);
    try expect(source, sink.captures(), "[<Struct>]", .attribute);
    try expect(source, sink.captures(), "Shape", .type);
    try expect(source, sink.captures(), "Circle", .constructor);
    try expect(source, sink.captures(), "radius", .property);
    try expect(source, sink.captures(), "Count", .property);
    try expect(source, sink.captures(), "area", .function);
    try expect(source, sink.captures(), "shape", .parameter);
    try expect(source, sink.captures(), "scale", .function);
    try expect(source, sink.captures(), "factor", .parameter);
    try expect(source, sink.captures(), "loop", .function);
    try expect(source, sink.captures(), "this", .parameter);
    try expect(source, sink.captures(), "Run", .function);
    try expect(source, sink.captures(), "input", .parameter);
    try expect(source, sink.captures(), "?limit", .parameter);
}

test "F# fused scanner preserves rendered output" {
    const source = "namespace Demo.Core\n[<Struct>]\ntype Shape = | Circle of float\nlet area (shape: Shape) = 42.0";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(source, sink.captures(), std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "<span class=\"syntax-keyword\">namespace</span> <span class=\"syntax-namespace\">Demo</span><span class=\"syntax-namespace syntax-punctuation\">.</span><span class=\"syntax-namespace\">Core</span>\n" ++
            "<span class=\"syntax-attribute\">[&lt;Struct&gt;]</span>\n" ++
            "<span class=\"syntax-keyword\">type</span> <span class=\"syntax-type\">Shape</span> <span class=\"syntax-operator\">=</span> <span class=\"syntax-operator\">|</span> <span class=\"syntax-constructor\">Circle</span> <span class=\"syntax-keyword\">of</span> <span class=\"syntax-builtin syntax-type\">float</span>\n" ++
            "<span class=\"syntax-keyword\">let</span> <span class=\"syntax-function\">area</span> <span class=\"syntax-punctuation\">(</span><span class=\"syntax-parameter\">shape</span><span class=\"syntax-operator\">:</span> <span class=\"syntax-type\">Shape</span><span class=\"syntax-punctuation\">)</span> <span class=\"syntax-operator\">=</span> <span class=\"syntax-number\">42.0</span>",
        output.written(),
    );
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
