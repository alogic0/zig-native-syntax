const backend_api = @import("backend.zig");
const capture_api = @import("capture.zig");
const html = @import("html.zig");
const Scope = @import("scope.zig").Scope;
const Backend = backend_api.Backend;
const Capture = capture_api.Capture;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Span = capture_api.Span;

/// Highlights a source subrange with another backend and translates every
/// nested capture back into the parent source coordinate space.
///
/// The region is half-open and must lie within `source`. The destination sink
/// must belong to the complete parent source. The region receives the
/// `embedded` scope, while parent and nested scopes are otherwise preserved and
/// combined by the renderer's normal overlap rules.
pub fn highlightEmbedded(
    source: []const u8,
    region: Span,
    nested_backend: Backend,
    sink: *CaptureSink,
) HighlightError!void {
    if (source.len != sink.source_len) return error.SourceLengthMismatch;
    try region.validate(source.len);

    const nested_source = source[region.start..region.end];
    var nested_sink: CaptureSink = .init(sink.allocator, nested_source.len);
    defer nested_sink.deinit();
    try nested_backend.highlight(nested_source, &nested_sink);

    try sink.add(region.start, region.end, .embedded);
    for (nested_sink.captures()) |capture| {
        try capture.validate(nested_source.len);
        try sink.add(
            region.start + capture.span.start,
            region.start + capture.span.end,
            capture.scope,
        );
    }
}

const std = @import("std");

fn highlightNested(source: []const u8, sink: *CaptureSink) HighlightError!void {
    if (source.len >= 3) {
        try sink.add(0, 1, .keyword);
        try sink.add(1, 3, .string);
    }
}

const test_nested_backend: Backend = .init(.{
    .canonical_name = "nested-test",
    .display_name = "Nested Test",
    .kind = .lexical,
}, highlightNested);

test "embedded captures translate into parent offsets" {
    const source = "before abc after";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try highlightEmbedded(source, .{ .start = 7, .end = 10 }, test_nested_backend, &sink);

    try std.testing.expectEqual(@as(usize, 3), sink.captures().len);
    try expectCapture(sink.captures(), 7, 10, .embedded);
    try expectCapture(sink.captures(), 7, 8, .keyword);
    try expectCapture(sink.captures(), 8, 10, .string);
}

test "embedded regions validate before invoking the nested backend" {
    const source = "abc";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try std.testing.expectError(
        error.ReversedRange,
        highlightEmbedded(source, .{ .start = 2, .end = 1 }, test_nested_backend, &sink),
    );
    try std.testing.expectError(
        error.RangeOutOfBounds,
        highlightEmbedded(source, .{ .start = 1, .end = 4 }, test_nested_backend, &sink),
    );
    try std.testing.expectEqual(@as(usize, 0), sink.captures().len);
}

test "empty embedded regions add no captures" {
    const source = "abc";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try highlightEmbedded(source, .{ .start = 1, .end = 1 }, test_nested_backend, &sink);
    try std.testing.expectEqual(@as(usize, 0), sink.captures().len);
}

test "embedded scopes combine with parent captures during rendering" {
    const source = "xabcx";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try sink.add(1, 4, .string);
    try highlightEmbedded(source, .{ .start = 1, .end = 4 }, test_nested_backend, &sink);

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try html.render(source, sink.captures(), std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "x<span class=\"syntax-embedded syntax-keyword syntax-string\">a</span>" ++
            "<span class=\"syntax-embedded syntax-string\">bc</span>x",
        output.written(),
    );
}

fn expectCapture(
    captures: []const Capture,
    start: usize,
    end: usize,
    scope: Scope,
) !void {
    for (captures) |capture| {
        if (capture.span.start == start and
            capture.span.end == end and
            capture.scope == scope) return;
    }
    return error.TestExpectedEqual;
}
