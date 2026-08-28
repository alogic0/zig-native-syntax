const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.python.backend;

test "Python backend metadata is stable" {
    try std.testing.expectEqualStrings("python", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
}

test "Python parser assigns declarations parameters imports and member roles" {
    const source =
        \\from pathlib import Path as FilePath
        \\@decorator
        \\class Entry:
        \\    def render(self, count: int = 1) -> str:
        \\        result = Path("demo")
        \\        return self.name.upper()
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "pathlib", .namespace);
    try expectCapture(source, sink.captures(), "FilePath", .namespace);
    try expectCapture(source, sink.captures(), "@decorator", .attribute);
    try expectCapture(source, sink.captures(), "Entry", .type);
    try expectCapture(source, sink.captures(), "render", .function);
    try expectCapture(source, sink.captures(), "self", .parameter);
    try expectCapture(source, sink.captures(), "count", .parameter);
    try expectCapture(source, sink.captures(), "int", .type);
    try expectCapture(source, sink.captures(), "str", .type);
    try expectCapture(source, sink.captures(), "Path", .constructor);
    try expectCapture(source, sink.captures(), "name", .property);
    try expectCapture(source, sink.captures(), "upper", .function);
    try expectCapture(source, sink.captures(), "upper", .property);
}

test "Python parser recovers structural roles after a malformed suite" {
    const source = "def broken(first, second: Missing):\nnext_value = call()\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "broken", .function);
    try expectCapture(source, sink.captures(), "first", .parameter);
    try expectCapture(source, sink.captures(), "Missing", .type);
    try expectCapture(source, sink.captures(), "call", .function);
}

test "Python representative application corpora retain structural roles" {
    for ([_][]const u8{
        @embedFile("corpus/python/complete.py"),
        @embedFile("corpus/python/async_service.py"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);

        try std.testing.expect(hasScope(sink.captures(), .function));
        try std.testing.expect(hasScope(sink.captures(), .parameter));
        try std.testing.expect(hasScope(sink.captures(), .type));
        try std.testing.expect(hasScope(sink.captures(), .property));
    }
}

fn expectCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| if (capture.scope == expected) return true;
    return false;
}

test "Python parser conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'd', 'e', 'f', ' ', 0xff, '(', ')', ':' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/python/complete.py"),
            .required_scopes = &.{ .comment, .attribute, .keyword, .function, .type, .builtin, .variable, .string, .escape, .boolean, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "def broken(x:\n    return \"unterminated\\n<&>",
            .required_scopes = &.{ .keyword, .function, .parameter, .string, .escape, .punctuation },
        },
        .multiline = .{
            .source = "text = \"\"\"first\nsecond <&>\"\"\"\n# done\n",
            .required_scopes = &.{ .variable, .string, .comment },
        },
        .escapable = .{
            .source = "value = \"<&>\\\"'\"",
            .required_scopes = &.{ .variable, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .punctuation },
        },
    });
}
