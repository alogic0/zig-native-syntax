const std = @import("std");

pub const IdentifierStyle = enum { ascii, callable, apostrophe };
pub const SegmentStart = enum { identifier, uppercase };

/// Advances over one valid UTF-8 scalar and retains arbitrary-byte recovery
/// for malformed or truncated input.
pub fn validUtf8Length(source: []const u8) usize {
    if (source.len == 0) return 0;
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

pub fn previousNonSpace(source: []const u8, before: usize) ?u8 {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return if (cursor > 0) source[cursor - 1] else null;
}

pub fn wordIs(word: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

pub fn wordIsIgnoreCase(word: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| if (std.ascii.eqlIgnoreCase(word, candidate)) return true;
    return false;
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

pub fn isAsciiIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

pub noinline fn identifierEnd(source: []const u8, start: usize, style: IdentifierStyle) usize {
    var end = start + 1;
    while (end < source.len and
        (std.ascii.isAlphanumeric(source[end]) or source[end] == '_' or
            (style == .apostrophe and source[end] == '\''))) end += 1;
    if (style == .callable and end < source.len and
        (source[end] == '!' or source[end] == '?')) end += 1;
    return end;
}

pub noinline fn qualifiedIdentifierEnd(
    source: []const u8,
    start: usize,
    separator: []const u8,
    style: IdentifierStyle,
    segment_start: SegmentStart,
) usize {
    var end = identifierEnd(source, start, style);
    while (end + separator.len < source.len and
        std.mem.startsWith(u8, source[end..], separator) and
        validSegmentStart(source[end + separator.len], segment_start))
    {
        end = identifierEnd(source, end + separator.len, style);
    }
    return end;
}

fn validSegmentStart(byte: u8, policy: SegmentStart) bool {
    return switch (policy) {
        .identifier => isAsciiIdentifierStart(byte),
        .uppercase => std.ascii.isUpper(byte),
    };
}

pub noinline fn stringEnd(source: []const u8, start: usize, quote: u8, allow_triple: bool) usize {
    const triple = allow_triple and start + 2 < source.len and
        source[start + 1] == quote and source[start + 2] == quote;
    if (!triple) return quotedEnd(source, start, quote, true);

    var index = start + 3;
    while (index < source.len) {
        if (source[index] == '\\') {
            index = escapeEnd(source, index);
        } else if (index + 2 < source.len and source[index] == quote and
            source[index + 1] == quote and source[index + 2] == quote)
        {
            return index + 3;
        } else {
            index += validUtf8Length(source[index..]);
        }
    }
    return index;
}

pub fn matchingDelimiter(opening: u8) u8 {
    return switch (opening) {
        '(' => ')',
        '[' => ']',
        '{' => '}',
        '<' => '>',
        else => opening,
    };
}

pub fn onlyIndentBefore(source: []const u8, line_start: usize, position: usize) bool {
    for (source[line_start..position]) |byte| {
        if (byte != ' ' and byte != '\t') return false;
    }
    return true;
}

test "shared identifier policies preserve language-specific spelling" {
    try std.testing.expectEqual(@as(usize, 6), identifierEnd("ready? next", 0, .callable));
    try std.testing.expectEqual(@as(usize, 6), identifierEnd("value' next", 0, .apostrophe));
    try std.testing.expectEqual(@as(usize, 16), qualifiedIdentifierEnd("Demo.HTTP.Server", 0, ".", .ascii, .uppercase));
    try std.testing.expectEqual(@as(usize, 18), qualifiedIdentifierEnd("Demo::HTTP::Server", 0, "::", .ascii, .identifier));
}

test "shared string scanner handles single and triple quotes" {
    try std.testing.expectEqual(@as(usize, 7), stringEnd("\"value\" tail", 0, '"', true));
    try std.testing.expectEqual(@as(usize, 13), stringEnd("\"\"\"value\\n\"\"\" tail", 0, '"', true));
}
