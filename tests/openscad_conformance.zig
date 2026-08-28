const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.openscad.backend;

test "OpenSCAD backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/openscad/complete.txt"), .required_scopes = &.{ .keyword, .function, .parameter, .property, .variable, .constant, .string, .escape, .number, .boolean, .comment } },
        .malformed = .{ .source = "module open(size = [1, 2) { cube(size = \"unterminated\\q<&>\n", .required_scopes = &.{ .keyword, .function, .parameter, .property, .string, .escape } },
        .multiline = .{ .source = "module one(value) { cube(size = value); }\nfunction two(other) = other;\n", .required_scopes = &.{ .function, .parameter, .property } },
        .escapable = .{ .source = "value = \"<&>\\q'\"; // comment", .required_scopes = &.{ .variable, .string, .escape, .comment } },
    });
}

test "OpenSCAD parser classifies modules functions parameters bindings calls and named arguments" {
    const source = @embedFile("corpus/openscad/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "rounded_box", .function);
    try expect(source, sink.captures(), "size", .parameter);
    try expect(source, sink.captures(), "radius", .parameter);
    try expect(source, sink.captures(), "local_size", .variable);
    try expect(source, sink.captures(), "translate", .function);
    try expect(source, sink.captures(), "cube", .function);
    try expect(source, sink.captures(), "center", .property);
    try expect(source, sink.captures(), "doubled", .function);
    try expect(source, sink.captures(), "value", .parameter);
    try expect(source, sink.captures(), "item", .variable);
    try expect(source, sink.captures(), "offset", .variable);
    try expect(source, sink.captures(), "undef", .constant);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
