const std = @import("std");
const syntax = @import("native_syntax");

fn recoverSource(
    allocator: std.mem.Allocator,
    rendered: []const u8,
) ![]u8 {
    var recovered: std.ArrayList(u8) = .empty;
    errdefer recovered.deinit(allocator);

    var index: usize = 0;
    while (index < rendered.len) {
        const remaining = rendered[index..];

        if (std.mem.startsWith(u8, remaining, "<span class=\"syntax-")) {
            const tag_end = std.mem.indexOfScalar(u8, remaining, '>') orelse {
                return error.UnterminatedGeneratedSpan;
            };
            index += tag_end + 1;
            continue;
        }
        if (std.mem.startsWith(u8, remaining, "</span>")) {
            index += "</span>".len;
            continue;
        }

        const entities = [_]struct { []const u8, u8 }{
            .{ "&amp;", '&' },
            .{ "&lt;", '<' },
            .{ "&gt;", '>' },
            .{ "&quot;", '"' },
            .{ "&#39;", '\'' },
        };
        for (entities) |entity| {
            if (std.mem.startsWith(u8, remaining, entity[0])) {
                try recovered.append(allocator, entity[1]);
                index += entity[0].len;
                break;
            }
        } else {
            if (rendered[index] == '<' or rendered[index] == '&') {
                return error.UnexpectedGeneratedMarkup;
            }
            try recovered.append(allocator, rendered[index]);
            index += 1;
        }
    }

    return recovered.toOwnedSlice(allocator);
}

fn nextRandom(state: *u64) u64 {
    state.* = state.* *% 6364136223846793005 +% 1442695040888963407;
    return state.*;
}

test "plain and classified rendering recover every input byte" {
    var source: [256]u8 = undefined;
    for (&source, 0..) |*byte, value| byte.* = @intCast(value);

    const captures = [_]syntax.Capture{
        try .init(0, 96, .comment),
        try .init(32, 160, .string),
        try .init(64, 224, .embedded),
        try .init(128, 256, .invalid),
    };

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(&source, &captures, std.testing.allocator, &output.writer);

    const recovered = try recoverSource(std.testing.allocator, output.written());
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualSlices(u8, &source, recovered);
}

test "random valid captures always preserve the original bytes" {
    const scopes = std.enums.values(syntax.Scope);
    var random_state: u64 = 0x87f4_a21d_b358_09ce;

    var source: [96]u8 = undefined;
    var captures: [32]syntax.Capture = undefined;

    for (0..128) |_| {
        const source_len: usize = @intCast(nextRandom(&random_state) % (source.len + 1));
        for (source[0..source_len]) |*byte| {
            byte.* = @truncate(nextRandom(&random_state));
        }

        const capture_len: usize = @intCast(nextRandom(&random_state) % (captures.len + 1));
        for (captures[0..capture_len]) |*item| {
            const first: usize = @intCast(nextRandom(&random_state) % (source_len + 1));
            const second: usize = @intCast(nextRandom(&random_state) % (source_len + 1));
            const start = @min(first, second);
            const end = @max(first, second);
            const scope_index: usize = @intCast(nextRandom(&random_state) % scopes.len);
            item.* = try .init(start, end, scopes[scope_index]);
        }

        var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
        defer output.deinit();
        try syntax.html.render(
            source[0..source_len],
            captures[0..capture_len],
            std.testing.allocator,
            &output.writer,
        );

        const recovered = try recoverSource(std.testing.allocator, output.written());
        defer std.testing.allocator.free(recovered);
        try std.testing.expectEqualSlices(u8, source[0..source_len], recovered);
    }
}

test "source cannot escape generated spans or create HTML" {
    const source =
        \\</span><script>alert("captured")</script>
        \\<img src=x onerror='uncaptured'>
    ;
    const first_line_end = std.mem.indexOfScalar(u8, source, '\n').?;
    const captures = [_]syntax.Capture{
        try .init(0, first_line_end, .string),
    };

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(source, &captures, std.testing.allocator, &output.writer);

    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<script") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<img") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "\"captured\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "'uncaptured'") == null);

    const recovered = try recoverSource(std.testing.allocator, output.written());
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualStrings(source, recovered);
}

test "newline forms remain byte-exact across capture boundaries" {
    const source = "line one\r\nline two\nline three\rline four";
    const captures = [_]syntax.Capture{
        try .init(0, 9, .comment),
        try .init(8, 20, .documentation),
        try .init(19, source.len, .string),
    };

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(source, &captures, std.testing.allocator, &output.writer);

    const recovered = try recoverSource(std.testing.allocator, output.written());
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualStrings(source, recovered);
}

test "random invalid ranges fail before rendering" {
    const source = "0123456789abcdef";
    var random_state: u64 = 0xd061_65ec_9af3_42b7;

    for (0..512) |_| {
        const start: usize = @intCast(nextRandom(&random_state) % 24);
        const end: usize = @intCast(nextRandom(&random_state) % 24);
        const captures = [_]syntax.Capture{.{
            .span = .{ .start = start, .end = end },
            .scope = .special,
        }};
        var discard_buffer: [32]u8 = undefined;
        var discarding: std.Io.Writer.Discarding = .init(&discard_buffer);

        if (start > end) {
            try std.testing.expectError(
                error.ReversedRange,
                syntax.html.render(
                    source,
                    &captures,
                    std.testing.allocator,
                    &discarding.writer,
                ),
            );
        } else if (end > source.len) {
            try std.testing.expectError(
                error.RangeOutOfBounds,
                syntax.html.render(
                    source,
                    &captures,
                    std.testing.allocator,
                    &discarding.writer,
                ),
            );
        } else {
            try syntax.html.render(
                source,
                &captures,
                std.testing.allocator,
                &discarding.writer,
            );
        }
    }
}
