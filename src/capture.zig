const std = @import("std");
const Scope = @import("scope.zig").Scope;

pub const ValidationError = error{
    ReversedRange,
    RangeOutOfBounds,
};

/// A half-open byte range `[start, end)` in borrowed source text.
pub const Span = struct {
    start: usize,
    end: usize,

    pub const Relation = enum {
        before,
        adjacent_before,
        overlaps_before,
        identical,
        contains,
        contained_by,
        overlaps_after,
        adjacent_after,
        after,
    };

    pub fn init(start: usize, end: usize) ValidationError!Span {
        const span: Span = .{ .start = start, .end = end };
        try span.validate(std.math.maxInt(usize));
        return span;
    }

    pub fn validate(span: Span, source_len: usize) ValidationError!void {
        if (span.start > span.end) return error.ReversedRange;
        if (span.end > source_len) return error.RangeOutOfBounds;
    }

    pub fn len(span: Span) usize {
        return span.end - span.start;
    }

    pub fn isEmpty(span: Span) bool {
        return span.start == span.end;
    }

    pub fn slice(span: Span, source: []const u8) ValidationError![]const u8 {
        try span.validate(source.len);
        return source[span.start..span.end];
    }

    pub fn relationTo(span: Span, other: Span) Relation {
        if (span.end < other.start) return .before;
        if (span.end == other.start) return .adjacent_before;
        if (span.start > other.end) return .after;
        if (span.start == other.end) return .adjacent_after;

        if (span.start == other.start and span.end == other.end) {
            return .identical;
        }
        if (span.start <= other.start and span.end >= other.end) {
            return .contains;
        }
        if (span.start >= other.start and span.end <= other.end) {
            return .contained_by;
        }
        if (span.start < other.start) return .overlaps_before;
        return .overlaps_after;
    }
};

/// A syntax classification applied to a source span.
///
/// Empty captures are valid and are ignored by renderers. Identical, nested,
/// and crossing captures are also valid; normalization defines how their
/// scopes combine into renderable segments.
pub const Capture = struct {
    span: Span,
    scope: Scope,

    pub fn init(start: usize, end: usize, scope: Scope) ValidationError!Capture {
        return .{
            .span = try .init(start, end),
            .scope = scope,
        };
    }

    pub fn validate(capture: Capture, source_len: usize) ValidationError!void {
        try capture.span.validate(source_len);
    }
};

test "span initialization rejects reversed ranges" {
    try std.testing.expectError(error.ReversedRange, Span.init(2, 1));
}

test "span validation checks source bounds without offset arithmetic" {
    const valid: Span = .{ .start = 3, .end = 3 };
    try valid.validate(3);
    try std.testing.expect(valid.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), valid.len());

    const past_end: Span = .{ .start = 3, .end = 4 };
    try std.testing.expectError(error.RangeOutOfBounds, past_end.validate(3));

    const reversed: Span = .{ .start = 4, .end = 3 };
    try std.testing.expectError(error.ReversedRange, reversed.validate(3));
}

test "span slice validates before indexing" {
    const source = "abcdef";
    try std.testing.expectEqualStrings("bcd", try (Span{ .start = 1, .end = 4 }).slice(source));
    try std.testing.expectError(
        error.RangeOutOfBounds,
        (Span{ .start = 0, .end = 7 }).slice(source),
    );
}

test "span relationships are explicit" {
    const subject: Span = .{ .start = 3, .end = 7 };

    const cases = [_]struct { Span, Span.Relation }{
        .{ .{ .start = 8, .end = 9 }, .before },
        .{ .{ .start = 7, .end = 9 }, .adjacent_before },
        .{ .{ .start = 5, .end = 9 }, .overlaps_before },
        .{ .{ .start = 3, .end = 7 }, .identical },
        .{ .{ .start = 4, .end = 6 }, .contains },
        .{ .{ .start = 2, .end = 8 }, .contained_by },
        .{ .{ .start = 1, .end = 5 }, .overlaps_after },
        .{ .{ .start = 1, .end = 3 }, .adjacent_after },
        .{ .{ .start = 1, .end = 2 }, .after },
    };

    for (cases) |case| {
        try std.testing.expectEqual(case[1], subject.relationTo(case[0]));
    }
}

test "capture validation permits overlapping ranges" {
    const outer = try Capture.init(1, 5, .builtin);
    const crossing = try Capture.init(3, 7, .type);

    try outer.validate(7);
    try crossing.validate(7);
    try std.testing.expectEqual(Span.Relation.overlaps_before, outer.span.relationTo(crossing.span));
}
