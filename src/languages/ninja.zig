const std = @import("std");
const api = @import("../backend.zig");
const utf8 = @import("../utf8.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "ninja",
    .display_name = "Ninja",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = logicalLineEnd(source, line_start);
        try scanLine(source, line_start, line_end, sink);
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn scanLine(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor = start;
    while (cursor < end and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    if (cursor == end) return;
    if (source[cursor] == '#') {
        try sink.add(cursor, end, .comment);
        return;
    }
    const word_start = cursor;
    while (cursor < end and isNameByte(source[cursor])) cursor += 1;
    const word = source[word_start..cursor];
    if (isKeyword(word)) {
        try sink.add(word_start, cursor, .keyword);
        while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
        if (std.mem.eql(u8, word, "build")) try scanBuild(source, cursor, end, sink) else if (cursor < end) try sink.add(cursor, end, if (std.mem.eql(u8, word, "include") or std.mem.eql(u8, word, "subninja")) .string else .label);
        return;
    }
    if (findAssignment(source, cursor, end)) |equals| {
        const key = std.mem.trim(u8, source[start..equals], " \t");
        const key_at = start + std.mem.indexOf(u8, source[start..equals], key).?;
        try sink.add(key_at, key_at + key.len, .property);
        try sink.add(equals, equals + 1, .operator);
        try scanValue(source, equals + 1, end, sink);
    }
}

fn scanBuild(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor = start;
    while (cursor < end and source[cursor] != ':') {
        while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
        const item_start = cursor;
        while (cursor < end and !std.ascii.isWhitespace(source[cursor]) and source[cursor] != ':') cursor += 1;
        if (item_start < cursor) try sink.add(item_start, cursor, .label);
    }
    if (cursor == end) return;
    try sink.add(cursor, cursor + 1, .operator);
    cursor += 1;
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    const rule_start = cursor;
    while (cursor < end and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (rule_start < cursor) try sink.add(rule_start, cursor, .type);
    while (cursor < end) {
        while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
        const input_start = cursor;
        while (cursor < end and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
        if (input_start < cursor) try sink.add(input_start, cursor, .string);
    }
}

fn scanValue(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor = start;
    while (cursor < end) switch (source[cursor]) {
        '#' => {
            if (cursor == start or source[cursor - 1] != '$') {
                try sink.add(cursor, end, .comment);
                return;
            }
            cursor += 1;
        },
        '$' => cursor = try scanDollar(source, cursor, end, sink),
        '"', '\'' => cursor = try scanString(source, cursor, end, sink),
        '0'...'9' => {
            const number_start = cursor;
            while (cursor < end and std.ascii.isDigit(source[cursor])) cursor += 1;
            try sink.add(number_start, cursor, .number);
        },
        else => cursor += 1,
    };
}

fn scanDollar(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    var cursor = start + 1;
    if (cursor < end and source[cursor] == '{') {
        cursor += 1;
        while (cursor < end and source[cursor] != '}') cursor += 1;
        if (cursor < end) cursor += 1;
        try sink.add(start, cursor, .variable);
    } else if (cursor < end and isNameByte(source[cursor])) {
        while (cursor < end and isNameByte(source[cursor])) cursor += 1;
        try sink.add(start, cursor, .variable);
    } else {
        cursor = @min(cursor + 1, end);
        try sink.add(start, cursor, .escape);
    }
    return cursor;
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

fn logicalLineEnd(source: []const u8, start: usize) usize {
    var end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
    while (end > start and source[end - 1] == '$' and end < source.len) end = std.mem.indexOfScalarPos(u8, source, end + 1, '\n') orelse source.len;
    return end;
}

fn findAssignment(source: []const u8, start: usize, end: usize) ?usize {
    var cursor = start;
    while (cursor < end) : (cursor += 1) if (source[cursor] == '=' and (cursor == start or source[cursor - 1] != '$')) return cursor;
    return null;
}

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "build", "default", "include", "pool", "rule", "subninja" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

fn isNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}
