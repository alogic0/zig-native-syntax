const std = @import("std");
const api = @import("../backend.zig");
const utf8 = @import("../utf8.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "po",
    .display_name = "Gettext PO",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        try scanLine(source, line_start, line_end, sink);
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn scanLine(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor = start;
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (cursor == end) return;
    if (source[cursor] == '#') {
        const scope: @import("../scope.zig").Scope = if (cursor + 1 < end and (source[cursor + 1] == ':' or source[cursor + 1] == ',')) .attribute else .comment;
        try sink.add(cursor, end, scope);
        if (cursor + 1 < end and source[cursor + 1] == '.') try sink.add(cursor, end, .documentation);
        return;
    }
    if (source[cursor] == '"') {
        _ = try scanString(source, cursor, end, sink);
        return;
    }
    const keyword_start = cursor;
    while (cursor < end and (std.ascii.isAlphabetic(source[cursor]) or source[cursor] == '_')) cursor += 1;
    if (!isKeyword(source[keyword_start..cursor])) return;
    try sink.add(keyword_start, cursor, .keyword);
    if (cursor < end and source[cursor] == '[') {
        try sink.add(cursor, cursor + 1, .punctuation);
        cursor += 1;
        const number_start = cursor;
        while (cursor < end and std.ascii.isDigit(source[cursor])) cursor += 1;
        if (number_start < cursor) try sink.add(number_start, cursor, .number);
        if (cursor < end and source[cursor] == ']') {
            try sink.add(cursor, cursor + 1, .punctuation);
            cursor += 1;
        }
    }
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (cursor < end and source[cursor] == '"') _ = try scanString(source, cursor, end, sink);
}

fn scanString(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    var cursor = start + 1;
    while (cursor < end) {
        if (source[cursor] == '\\') {
            const escape_end = utf8.escapedSequenceEnd(source, cursor, end);
            try sink.add(cursor, escape_end, .escape);
            cursor = escape_end;
        } else {
            cursor += 1;
            if (source[cursor - 1] == '"') break;
        }
    }
    try sink.add(start, cursor, .string);
    return cursor;
}

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "domain", "msgctxt", "msgid", "msgid_plural", "msgstr" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
