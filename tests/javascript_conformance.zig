const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.javascript.backend;

test "JavaScript backend metadata is stable" {
    try std.testing.expectEqualStrings("javascript", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
}

test "JavaScript parser conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'c', 'o', 'n', 's', 't', ' ', 0xff, '=', '1', ';' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/javascript/complete.js"),
            .required_scopes = &.{ .comment, .documentation, .keyword, .type, .function, .property, .builtin, .variable, .string, .escape, .boolean, .constant, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "function broken(value { return `unfinished ${value}\\n<&>",
            .required_scopes = &.{ .keyword, .function, .parameter, .string, .escape, .punctuation },
        },
        .multiline = .{
            .source = "/* open\ncomment <&> */\nconst text = `first\nsecond`;\n",
            .required_scopes = &.{ .comment, .keyword, .variable, .string },
        },
        .escapable = .{
            .source = "const value = \"<&>\\\"'\";",
            .required_scopes = &.{ .keyword, .variable, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .number, .operator, .punctuation },
        },
    });
}

test "JavaScript parser uses syntax context for identifier roles" {
    const source = "function greet(name) { const result = service.run(name); }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectScopeAt(source, sink.captures(), "greet", .function);
    try expectScopeAt(source, sink.captures(), "name", .parameter);
    try expectScopeAt(source, sink.captures(), "result", .variable);
    try expectScopeAt(source, sink.captures(), "run", .property);
    try expectScopeAt(source, sink.captures(), "run", .function);
}

fn expectScopeAt(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    const start = std.mem.indexOf(u8, source, text) orelse return error.TestExpectedEqual;
    for (captures) |capture| {
        if (capture.span.start == start and capture.span.end == start + text.len and capture.scope == scope) return;
    }
    return error.TestExpectedEqual;
}
