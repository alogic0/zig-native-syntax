const std = @import("std");

/// Advances over one valid UTF-8 scalar and retains arbitrary-byte recovery
/// for malformed or truncated input.
pub fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}

pub fn nextNonSpace(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

pub fn lineEnd(source: []const u8, start: usize, limit: usize) usize {
    return @min(std.mem.indexOfScalarPos(u8, source, start, '\n') orelse limit, limit);
}

pub fn blockCommentEnd(source: []const u8, start: usize, limit: usize) usize {
    const close = std.mem.indexOfPos(u8, source, start + 2, "*/") orelse return limit;
    return @min(close + 2, limit);
}

pub fn quotedEnd(source: []const u8, start: usize, quote: u8, stop_at_newline: bool) usize {
    var cursor = start + 1;
    while (cursor < source.len) {
        if (source[cursor] == '\\') {
            cursor = escapeEnd(source, cursor);
            continue;
        }
        cursor += 1;
        if (source[cursor - 1] == quote or (stop_at_newline and source[cursor - 1] == '\n')) break;
    }
    return cursor;
}

pub fn escapeEnd(source: []const u8, start: usize) usize {
    const escaped = start + 1;
    if (escaped >= source.len) return source.len;
    return escaped + validUtf8Length(source[escaped..]);
}
