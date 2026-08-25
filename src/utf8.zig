const std = @import("std");

pub fn validSequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

pub fn escapedSequenceEnd(source: []const u8, start: usize, limit: usize) usize {
    const escaped_start = start + 1;
    if (escaped_start >= limit) return limit;
    const len = validSequenceLength(source[escaped_start..limit]) orelse 1;
    return escaped_start + len;
}

test "escaped sequence consumes one complete scalar" {
    const source = "\\├";
    try std.testing.expectEqual(source.len, escapedSequenceEnd(source, 0, source.len));

    const invalid = [_]u8{ '\\', 0xff, 0x80 };
    try std.testing.expectEqual(@as(usize, 2), escapedSequenceEnd(&invalid, 0, invalid.len));
}
