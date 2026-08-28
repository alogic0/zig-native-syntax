const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "GDScript backend conforms" {
    try conformance.expectConforms(syntax.languages.gdscript.backend, .{
        .valid = .{ .source = @embedFile("corpus/gdscript/scene.gd"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .attribute, .type, .function, .parameter, .variable, .constant } },
        .malformed = .{ .source = "func broken(value: Thing:\n    var text = \"unterminated\nvar recovered = true\n", .required_scopes = &.{ .keyword, .function, .parameter, .type, .string, .variable, .boolean } },
        .multiline = .{ .source = "func first():\n    pass\nfunc second():\n    pass\n", .required_scopes = &.{ .keyword, .function } },
        .escapable = .{ .source = "var value = \"<&>\\q'\" # comment", .required_scopes = &.{ .keyword, .variable, .string, .escape, .comment } },
    });
}

test "GDScript parser classifies scene declarations" {
    const source = @embedFile("corpus/gdscript/scene.gd");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.gdscript.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "@tool", .attribute);
    try expect(source, sink.captures(), "Player", .type);
    try expect(source, sink.captures(), "CharacterBody2D", .type);
    try expect(source, sink.captures(), "health_changed", .function);
    try expect(source, sink.captures(), "value", .parameter);
    try expect(source, sink.captures(), "State", .type);
    try expect(source, sink.captures(), "IDLE", .constant);
    try expect(source, sink.captures(), "speed", .variable);
    try expect(source, sink.captures(), "Sprite2D", .type);
    try expect(source, sink.captures(), "$Sprite2D", .string);
    try expect(source, sink.captures(), "move_player", .function);
    try expect(source, sink.captures(), "direction", .parameter);
    try expect(source, sink.captures(), "normalized", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
