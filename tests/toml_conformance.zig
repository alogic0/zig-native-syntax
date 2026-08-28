const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.toml.backend;

test "TOML backend metadata is stable" {
    try std.testing.expectEqualStrings("toml", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
}

test "TOML scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'x', ' ', '=', ' ', '"', 0xff, '"' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/toml/complete.toml"),
            .required_scopes = &.{ .property, .namespace, .string, .escape, .boolean, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "[package\nvalue = \"unterminated\\u12<&>",
            .required_scopes = &.{ .namespace, .property, .string, .escape, .operator, .punctuation },
        },
        .multiline = .{
            .source = "text = \"\"\"first\nsecond\"\"\"\n# comment\n",
            .required_scopes = &.{ .property, .string, .comment },
        },
        .escapable = .{
            .source = "html = \"<&>\\\"'\"",
            .required_scopes = &.{ .property, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .property, .string, .operator },
        },
    });
}

test "TOML distinguishes keys, tables, and values" {
    const source =
        \\true = false
        \\123 = 456
        \\inf = nan
        \\[123.true]
        \\values = ["text", true, 1]
        \\inline = { true = false, 123 = 4 }
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCaptureAt(source, sink.captures(), 0, 4, .property);
    try expectCaptureAt(source, sink.captures(), 7, 12, .boolean);
    try expectCaptureAt(source, sink.captures(), 13, 16, .property);
    try expectCaptureAt(source, sink.captures(), 19, 22, .number);
    try expectCaptureAt(source, sink.captures(), 23, 26, .property);
    try expectCaptureAt(source, sink.captures(), 29, 32, .number);
    try expectCapture(source, sink.captures(), "123", .namespace);
    try expectCapture(source, sink.captures(), "true", .namespace);
    try expectCapture(source, sink.captures(), "\"text\"", .string);
    try expectCapture(source, sink.captures(), "values", .property);
    try expectCapture(source, sink.captures(), "inline", .property);
}

test "TOML representative project files retain exact lexical roles" {
    for ([_][]const u8{
        @embedFile("corpus/toml/Cargo.toml"),
        @embedFile("corpus/toml/pyproject.toml"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);

        try expectCapture(source, sink.captures(), "name", .property);
        try expectCapture(source, sink.captures(), "version", .property);
        try std.testing.expect(hasScope(sink.captures(), .namespace));
        try std.testing.expect(hasScope(sink.captures(), .string));
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

fn expectCaptureAt(
    source: []const u8,
    captures: []const syntax.Capture,
    start: usize,
    end: usize,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and capture.span.start == start and capture.span.end == end) {
            _ = try capture.span.slice(source);
            return;
        }
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| if (capture.scope == expected) return true;
    return false;
}
