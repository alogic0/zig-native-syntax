const std = @import("std");
const api = @import("../backend.zig");
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;
pub const backend: api.Backend = .init(.{
    .canonical_name = "hurl",
    .display_name = "Hurl",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var start: usize = 0;
    while (start < source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        const line = source[start..end];
        const indent = skipSpaces(line, 0);
        const trimmed = line[indent..];

        if (trimmed.len > 0 and trimmed[0] == '#') {
            try sink.add(start + indent, end, .comment);
        } else if (sectionEnd(trimmed)) |section_end| {
            try sink.add(start + indent, start + indent + section_end, .tag);
        } else if (firstWord(trimmed)) |word| {
            if (isMethod(word.text)) {
                try sink.add(start + indent + word.start, start + indent + word.end, .keyword);
                const url_start = skipSpaces(trimmed, word.end);
                if (url_start < trimmed.len) try sink.add(start + indent + url_start, end, .markup_link);
            } else if (std.mem.startsWith(u8, word.text, "HTTP/")) {
                try sink.add(start + indent + word.start, start + indent + word.end, .keyword);
                const status_start = skipSpaces(trimmed, word.end);
                const status_end = digitEnd(trimmed, status_start);
                if (status_start < status_end) try sink.add(start + indent + status_start, start + indent + status_end, .number);
            } else if (headerEnd(trimmed)) |header_end| {
                try sink.add(start + indent, start + indent + header_end, .property);
            } else if (isPredicate(word.text)) {
                try sink.add(start + indent + word.start, start + indent + word.end, .type);
            }
        }
        try scanInline(source, sink, start, end);
        start = if (end < source.len) end + 1 else end;
    }
}

const Word = struct { text: []const u8, start: usize, end: usize };
fn firstWord(line: []const u8) ?Word {
    const start = skipSpaces(line, 0);
    if (start == line.len) return null;
    var end = start;
    while (end < line.len and !std.ascii.isWhitespace(line[end])) end += 1;
    return .{ .text = line[start..end], .start = start, .end = end };
}
fn isMethod(word: []const u8) bool {
    const methods = [_][]const u8{ "GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH" };
    for (methods) |method| if (std.mem.eql(u8, word, method)) return true;
    return false;
}
fn isPredicate(word: []const u8) bool {
    const words = [_][]const u8{ "status", "url", "header", "body", "cookie", "jsonpath", "xpath", "regex", "duration", "bytes" };
    for (words) |candidate| if (std.ascii.eqlIgnoreCase(word, candidate)) return true;
    return false;
}
fn sectionEnd(line: []const u8) ?usize {
    if (line.len < 3 or line[0] != '[') return null;
    const close = std.mem.indexOfScalarPos(u8, line, 1, ']') orelse return null;
    return close + 1;
}
fn headerEnd(line: []const u8) ?usize {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    if (colon == 0 or (colon + 2 < line.len and line[colon + 1] == '/' and line[colon + 2] == '/')) return null;
    for (line[0..colon]) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-') return null;
    return colon + 1;
}
fn scanInline(source: []const u8, sink: *api.CaptureSink, start: usize, end: usize) api.HighlightError!void {
    var cursor = start;
    while (cursor < end) {
        if (cursor + 1 < end and source[cursor] == '{' and source[cursor + 1] == '{') {
            const close = std.mem.indexOfPos(u8, source[0..end], cursor + 2, "}}") orelse end - 2;
            const capture_end = @min(end, close + 2);
            try sink.add(cursor, capture_end, .variable);
            cursor = capture_end;
        } else if (source[cursor] == '"') {
            const string_start = cursor;
            cursor += 1;
            while (cursor < end) {
                if (source[cursor] == '\\') {
                    const escape_start = cursor;
                    cursor += 1;
                    if (cursor < end) cursor += validUtf8Length(source[cursor..end]);
                    try sink.add(escape_start, cursor, .escape);
                } else {
                    const byte = source[cursor];
                    cursor += 1;
                    if (byte == '"') break;
                }
            }
            try sink.add(string_start, cursor, .string);
        } else cursor += 1;
    }
}
fn skipSpaces(line: []const u8, from: usize) usize {
    var cursor = from;
    while (cursor < line.len and (line[cursor] == ' ' or line[cursor] == '\t')) cursor += 1;
    return cursor;
}
fn digitEnd(line: []const u8, from: usize) usize {
    var cursor = from;
    while (cursor < line.len and std.ascii.isDigit(line[cursor])) cursor += 1;
    return cursor;
}
