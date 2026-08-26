const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.sql.backend;

test "SQL backend metadata is stable" {
    try std.testing.expectEqualStrings("sql", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
}

test "SQL scanner distinguishes dialect-neutral lexical roles" {
    const source = "SELECT count(\"user_id\") FROM audit WHERE enabled = true AND id > :minimum AND owner = $1;";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "SELECT", .keyword);
    try expectCapture(source, sink.captures(), "count", .function);
    try expectCapture(source, sink.captures(), "\"user_id\"", .property);
    try expectCapture(source, sink.captures(), "true", .boolean);
    try expectCapture(source, sink.captures(), ":minimum", .parameter);
    try expectCapture(source, sink.captures(), "$1", .parameter);
}

test "SQL representative query corpora retain lexical roles" {
    for ([_][]const u8{
        @embedFile("corpus/sql/complete.sql"),
        @embedFile("corpus/sql/migration.sql"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);
        try std.testing.expect(hasScope(sink.captures(), .keyword));
        try std.testing.expect(hasScope(sink.captures(), .string));
        try std.testing.expect(hasScope(sink.captures(), .punctuation));
    }
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| if (capture.scope == expected) return true;
    return false;
}

test "SQL scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'S', 'E', 'L', 'E', 'C', 'T', ' ', 0xff };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/sql/complete.sql"),
            .required_scopes = &.{ .comment, .keyword, .property, .variable, .function, .string, .escape, .boolean, .number, .parameter, .operator, .punctuation },
        },
        .malformed = .{
            .source = "SELECT /* open\n name FROM t WHERE value = 'unterminated <&>",
            .required_scopes = &.{ .keyword, .comment },
        },
        .multiline = .{
            .source = "SELECT $$first\nsecond <&>$$, count(*)\nFROM items;\n",
            .required_scopes = &.{ .keyword, .string, .function, .operator },
        },
        .escapable = .{
            .source = "SELECT '<&>''\\n\"' AS value;",
            .required_scopes = &.{ .keyword, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{.keyword},
        },
    });
}
