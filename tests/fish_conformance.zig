const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "Fish backend conforms" {
    try conformance.expectConforms(syntax.languages.fish.backend, .{
        .valid = .{ .source = @embedFile("corpus/fish/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .function, .builtin, .variable, .parameter, .attribute } },
        .malformed = .{ .source = "printf \"unterminated\\u12<&>\nset next true\n", .required_scopes = &.{ .function, .builtin, .string, .escape, .keyword, .variable, .boolean } },
        .multiline = .{ .source = "echo first\nprintf second\n", .required_scopes = &.{ .function, .builtin } },
        .escapable = .{ .source = "printf \"<&>\\q'\" # comment", .required_scopes = &.{ .function, .builtin, .string, .escape, .comment } },
    });
}

test "Fish parser distinguishes declarations commands arguments and substitutions" {
    const source = "function greet --argument-names name\nset message (string upper $name)\nprintf '%s' $message | string collect\nend\ngreet Ada";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.fish.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "--argument-names", .attribute);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "message", .variable);
    try expect(source, sink.captures(), "string", .builtin);
    try expect(source, sink.captures(), "$name", .variable);
    try expect(source, sink.captures(), "printf", .function);
    try expect(source, sink.captures(), "$message", .variable);
}

test "Fish parser covers completion scripts continuations and redirections" {
    const source = @embedFile("corpus/fish/completions.fish");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.fish.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "__fish_viewer_needs_command", .function);
    try expect(source, sink.captures(), "tokens", .variable);
    try expect(source, sink.captures(), "commandline", .builtin);
    try expect(source, sink.captures(), "$tokens[1..-1]", .variable);
    try expect(source, sink.captures(), "find", .function);
    try expect(source, sink.captures(), "complete", .builtin);
    try expect(source, sink.captures(), "-n", .attribute);
    try expect(source, sink.captures(), "type", .builtin);
    try expect(source, sink.captures(), "string", .builtin);
    try expect(source, sink.captures(), "/usr/bin/printf", .function);
    try expect(source, sink.captures(), "$argv[1]", .variable);
    try expectMissing(source, sink.captures(), "dev", .function);
    try expectMissing(source, sink.captures(), "tmp", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectMissing(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return error.TestUnexpectedResult;
    }
}
