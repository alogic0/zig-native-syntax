const std = @import("std");
const Allocator = std.mem.Allocator;
const capture = @import("capture.zig");
const Capture = capture.Capture;
const Scope = @import("scope.zig").Scope;

pub const MetadataError = error{
    InvalidCanonicalName,
    EmptyDisplayName,
};

pub const HighlightError = Allocator.Error || capture.ValidationError || error{
    SourceLengthMismatch,
    SourceTooLarge,
};

pub const BackendKind = enum {
    lexical,
    parser_backed,
    composed,
};

pub const BackendInfo = struct {
    canonical_name: []const u8,
    display_name: []const u8,
    kind: BackendKind,

    pub fn validate(info: BackendInfo) MetadataError!void {
        if (!isCanonicalName(info.canonical_name)) {
            return error.InvalidCanonicalName;
        }
        if (info.display_name.len == 0) return error.EmptyDisplayName;
    }

    fn isCanonicalName(name: []const u8) bool {
        if (name.len == 0 or !std.ascii.isLower(name[0])) return false;

        for (name[1..]) |byte| {
            if (!std.ascii.isLower(byte) and
                !std.ascii.isDigit(byte) and
                byte != '-') return false;
        }

        return name[name.len - 1] != '-';
    }
};

/// Caller-owned storage used by a backend to report classifications.
///
/// Captures are validated against `source_len` as they are added. Empty
/// captures are valid but carry no rendering information, so the sink drops
/// them instead of storing them.
pub const CaptureSink = struct {
    allocator: Allocator,
    source_len: usize,
    list: std.ArrayList(Capture) = .empty,

    pub fn init(allocator: Allocator, source_len: usize) CaptureSink {
        return .{
            .allocator = allocator,
            .source_len = source_len,
        };
    }

    pub fn deinit(sink: *CaptureSink) void {
        sink.list.deinit(sink.allocator);
        sink.* = undefined;
    }

    pub fn add(
        sink: *CaptureSink,
        start: usize,
        end: usize,
        scope: Scope,
    ) (Allocator.Error || capture.ValidationError)!void {
        try sink.addCapture(.{
            .span = .{ .start = start, .end = end },
            .scope = scope,
        });
    }

    pub fn addCapture(
        sink: *CaptureSink,
        item: Capture,
    ) (Allocator.Error || capture.ValidationError)!void {
        try item.validate(sink.source_len);
        if (item.span.isEmpty()) return;
        try sink.list.append(sink.allocator, item);
    }

    pub fn captures(sink: *const CaptureSink) []const Capture {
        return sink.list.items;
    }

    /// Transfers ownership of the capture allocation to the caller.
    pub fn toOwnedSlice(sink: *CaptureSink) Allocator.Error![]Capture {
        return sink.list.toOwnedSlice(sink.allocator);
    }
};

pub const Backend = struct {
    pub const HighlightFn = *const fn (
        source: []const u8,
        sink: *CaptureSink,
    ) HighlightError!void;

    info: BackendInfo,
    highlight_fn: HighlightFn,

    pub fn init(comptime info: BackendInfo, highlight_fn: HighlightFn) Backend {
        comptime info.validate() catch |err| {
            @compileError("invalid backend metadata: " ++ @errorName(err));
        };

        return .{
            .info = info,
            .highlight_fn = highlight_fn,
        };
    }

    pub fn highlight(
        backend: Backend,
        source: []const u8,
        sink: *CaptureSink,
    ) HighlightError!void {
        if (source.len != sink.source_len) {
            return error.SourceLengthMismatch;
        }
        try backend.highlight_fn(source, sink);
    }
};

test "backend metadata uses canonical names rather than aliases" {
    try (BackendInfo{
        .canonical_name = "ziggy-schema",
        .display_name = "Ziggy Schema",
        .kind = .parser_backed,
    }).validate();

    const invalid_names = [_][]const u8{
        "",
        "Zig",
        "-zig",
        "zig-",
        "zig_schema",
        "zig schema",
    };
    for (invalid_names) |name| {
        try std.testing.expectError(error.InvalidCanonicalName, (BackendInfo{
            .canonical_name = name,
            .display_name = "test",
            .kind = .lexical,
        }).validate());
    }

    try std.testing.expectError(error.EmptyDisplayName, (BackendInfo{
        .canonical_name = "zig",
        .display_name = "",
        .kind = .parser_backed,
    }).validate());
}

test "capture sink validates and owns its allocation" {
    var sink: CaptureSink = .init(std.testing.allocator, 8);
    defer sink.deinit();

    try sink.add(0, 5, .keyword);
    try sink.add(5, 5, .punctuation);
    try std.testing.expectError(error.ReversedRange, sink.add(7, 6, .invalid));
    try std.testing.expectError(error.RangeOutOfBounds, sink.add(7, 9, .string));

    try std.testing.expectEqual(@as(usize, 1), sink.captures().len);
    try std.testing.expectEqual(Scope.keyword, sink.captures()[0].scope);
}

test "capture allocation can transfer to the caller" {
    var sink: CaptureSink = .init(std.testing.allocator, 4);
    defer sink.deinit();

    try sink.add(0, 4, .string);
    const owned = try sink.toOwnedSlice();
    defer std.testing.allocator.free(owned);

    try std.testing.expectEqual(@as(usize, 1), owned.len);
    try std.testing.expectEqual(@as(usize, 0), sink.captures().len);
}

fn highlightTestBackend(source: []const u8, sink: *CaptureSink) HighlightError!void {
    if (std.mem.startsWith(u8, source, "const")) {
        try sink.add(0, 5, .keyword);
    }
}

const test_backend: Backend = .init(.{
    .canonical_name = "test",
    .display_name = "Test",
    .kind = .lexical,
}, highlightTestBackend);

test "backend writes to caller-owned sink" {
    const source = "const value";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try test_backend.highlight(source, &sink);
    try std.testing.expectEqual(@as(usize, 1), sink.captures().len);
}

test "backend rejects a sink for different source bytes" {
    var sink: CaptureSink = .init(std.testing.allocator, 3);
    defer sink.deinit();

    try std.testing.expectError(
        error.SourceLengthMismatch,
        test_backend.highlight("four", &sink),
    );
    try std.testing.expectEqual(@as(usize, 0), sink.captures().len);
}
