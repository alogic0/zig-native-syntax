const std = @import("std");
const syntax = @import("native_syntax");
const html_recovery = @import("html_recovery.zig");

pub const Case = struct {
    source: []const u8,
    required_scopes: []const syntax.Scope = &.{},
};

/// Language-specific samples consumed by the shared backend contract tests.
/// Grammar knowledge stays in each backend's test root; this support module
/// owns only language-neutral invariants.
pub const Suite = struct {
    valid: Case,
    malformed: Case,
    multiline: Case,
    escapable: Case,
    invalid_utf8: ?Case = null,
    extra_cases: []const Case = &.{},
};

pub fn expectConforms(backend: syntax.Backend, suite: Suite) !void {
    try expectCase(backend, .{ .source = "" });
    try expectCase(backend, .{ .source = "├── Builds Docker image" });
    try expectCase(backend, .{ .source = "\"\\├\"" });
    try expectCase(backend, suite.valid);
    try expectCase(backend, suite.malformed);

    try std.testing.expect(std.mem.indexOfScalar(u8, suite.multiline.source, '\n') != null);
    try expectCase(backend, suite.multiline);

    for ("&<>\"'") |byte| {
        try std.testing.expect(std.mem.indexOfScalar(u8, suite.escapable.source, byte) != null);
    }
    try expectCase(backend, suite.escapable);

    if (suite.invalid_utf8) |invalid_utf8| {
        try std.testing.expect(!std.unicode.utf8ValidateSlice(invalid_utf8.source));
        try expectCase(backend, invalid_utf8);
    }

    for (suite.extra_cases) |case| try expectCase(backend, case);
}

fn expectCase(backend: syntax.Backend, case: Case) !void {
    var first: syntax.CaptureSink = .init(std.testing.allocator, case.source.len);
    defer first.deinit();
    try backend.highlight(case.source, &first);

    var second: syntax.CaptureSink = .init(std.testing.allocator, case.source.len);
    defer second.deinit();
    try backend.highlight(case.source, &second);

    try expectEqualCaptures(first.captures(), second.captures());
    for (first.captures()) |capture| try capture.validate(case.source.len);

    for (case.required_scopes) |required_scope| {
        try std.testing.expect(hasScope(first.captures(), required_scope));
    }

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(
        case.source,
        first.captures(),
        std.testing.allocator,
        &output.writer,
    );
    if (std.unicode.utf8ValidateSlice(case.source)) {
        try std.testing.expect(std.unicode.utf8ValidateSlice(output.written()));
    }

    const recovered = try html_recovery.recoverSource(
        std.testing.allocator,
        output.written(),
    );
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualSlices(u8, case.source, recovered);

    if (case.source.len == 0) {
        try std.testing.expectEqual(@as(usize, 0), first.captures().len);
        try std.testing.expectEqual(@as(usize, 0), output.written().len);
    }
}

fn expectEqualCaptures(
    expected: []const syntax.Capture,
    actual: []const syntax.Capture,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_capture, actual_capture| {
        try std.testing.expectEqual(expected_capture.span.start, actual_capture.span.start);
        try std.testing.expectEqual(expected_capture.span.end, actual_capture.span.end);
        try std.testing.expectEqual(expected_capture.scope, actual_capture.scope);
    }
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| {
        if (capture.scope == expected) return true;
    }
    return false;
}
