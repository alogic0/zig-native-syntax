const std = @import("std");
const api = @import("../backend.zig");
const utf8 = @import("../utf8.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "ssh-config",
    .display_name = "SSH config",
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
        try sink.add(cursor, end, .comment);
        return;
    }
    const directive_start = cursor;
    while (cursor < end and !std.ascii.isWhitespace(source[cursor]) and source[cursor] != '=') cursor += 1;
    try sink.add(directive_start, cursor, if (isSection(source[directive_start..cursor])) .keyword else .property);
    while (cursor < end) switch (source[cursor]) {
        '#' => {
            if (cursor == start or std.ascii.isWhitespace(source[cursor - 1])) {
                try sink.add(cursor, end, .comment);
                return;
            }
            cursor += 1;
        },
        '=' => {
            try sink.add(cursor, cursor + 1, .operator);
            cursor += 1;
        },
        '"', '\'' => cursor = try scanString(source, cursor, end, sink),
        '%' => {
            const token_end = @min(cursor + 2, end);
            try sink.add(cursor, token_end, .variable);
            cursor = token_end;
        },
        '0'...'9' => {
            const number_start = cursor;
            while (cursor < end and std.ascii.isDigit(source[cursor])) cursor += 1;
            try sink.add(number_start, cursor, .number);
        },
        else => if (std.ascii.isAlphabetic(source[cursor])) {
            const word_start = cursor;
            while (cursor < end and !std.ascii.isWhitespace(source[cursor]) and source[cursor] != '#') cursor += 1;
            const word = source[word_start..cursor];
            if (isBoolean(word)) try sink.add(word_start, cursor, .boolean);
        } else {
            cursor += 1;
        },
    };
}

fn scanString(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    const quote = source[start];
    var cursor = start + 1;
    while (cursor < end) {
        if (source[cursor] == '\\') {
            const escape_end = utf8.escapedSequenceEnd(source, cursor, end);
            try sink.add(cursor, escape_end, .escape);
            cursor = escape_end;
        } else {
            cursor += 1;
            if (source[cursor - 1] == quote) break;
        }
    }
    try sink.add(start, cursor, .string);
    return cursor;
}

fn isSection(word: []const u8) bool {
    return std.ascii.eqlIgnoreCase(word, "host") or std.ascii.eqlIgnoreCase(word, "match");
}

fn isBoolean(word: []const u8) bool {
    return std.ascii.eqlIgnoreCase(word, "yes") or std.ascii.eqlIgnoreCase(word, "no");
}
