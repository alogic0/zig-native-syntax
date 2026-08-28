const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "Typst backend conforms" {
    try conformance.expectConforms(syntax.languages.typst.backend, .{
        .valid = .{ .source = @embedFile("corpus/typst/report.typ"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .special, .embedded, .function, .parameter, .property, .variable, .label, .attribute } },
        .malformed = .{ .source = "#let broken(value = \"unterminated\n#let recovered = true\n$ x + y\n", .required_scopes = &.{ .special, .embedded, .keyword, .function, .parameter, .string, .variable, .boolean } },
        .multiline = .{ .source = "#let first = 1\n#let second = first + 1\n", .required_scopes = &.{ .special, .embedded, .keyword, .variable, .number } },
        .escapable = .{ .source = "#let value = \"<&>\\q'\" // comment", .required_scopes = &.{ .special, .embedded, .keyword, .variable, .string, .escape, .comment } },
    });
}

test "Typst composition classifies markup code math and raw blocks" {
    const source = @embedFile("corpus/typst/report.typ");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.typst.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "#", .special);
    try expect(source, sink.captures(), "badge", .function);
    try expect(source, sink.captures(), "body", .parameter);
    try expect(source, sink.captures(), "fill", .parameter);
    try expect(source, sink.captures(), "fill", .property);
    try expect(source, sink.captures(), "accent", .variable);
    try expect(source, sink.captures(), "rgb", .function);
    try expect(source, sink.captures(), "<report>", .label);
    try expect(source, sink.captures(), "@report", .label);
    try expect(source, sink.captures(), "rust", .attribute);
    try expect(source, sink.captures(), "$", .special);
    try expect(source, sink.captures(), "sum", .keyword);
    try expect(source, sink.captures(), "i", .variable);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
