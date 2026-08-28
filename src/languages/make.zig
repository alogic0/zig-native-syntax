const std = @import("std");
const utf8 = @import("../utf8.zig");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const bash = @import("bash.zig");
const Scope = @import("../scope.zig").Scope;

pub const backend: api.Backend = .init(.{
    .canonical_name = "make",
    .display_name = "Make",
    .kind = .composed,
    .support_level = .verified_structural,
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
    if (start < end and source[start] == '\t') {
        var recipe_cursor = start + 1;
        while (recipe_cursor < end and std.mem.indexOfScalar(u8, "@+-", source[recipe_cursor]) != null) {
            try sink.add(recipe_cursor, recipe_cursor + 1, .special);
            recipe_cursor += 1;
        }
        try composition.highlightEmbedded(source, .{ .start = recipe_cursor, .end = end }, bash.backend, sink);
        while (recipe_cursor < end) {
            if (source[recipe_cursor] == '$') {
                recipe_cursor = try scanVariable(source, recipe_cursor, end, sink);
            } else {
                recipe_cursor += 1;
            }
        }
        return;
    }
    var cursor = start;
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (cursor == end) return;
    if (source[cursor] == '#') {
        try sink.add(cursor, end, .comment);
        return;
    }

    const first_start = cursor;
    while (cursor < end and isNameByte(source[cursor])) cursor += 1;
    if (cursor > first_start and isDirective(source[first_start..cursor])) try sink.add(first_start, cursor, .keyword);

    var scan = start;
    while (scan < end) switch (source[scan]) {
        '#' => {
            if (scan == start or source[scan - 1] != '\\') try sink.add(scan, end, .comment);
            scan = end;
        },
        '$' => scan = try scanVariable(source, scan, end, sink),
        '"', '\'' => scan = try scanQuoted(source, scan, end, sink),
        ':', '=', '+', '?', '!' => scan = try scanOperator(source, scan, end, sink),
        else => scan += 1,
    };

    if (assignmentOperator(source[start..end])) |relative| {
        const key = std.mem.trim(u8, source[start .. start + relative], " \t");
        if (key.len > 0) {
            const key_start = start + std.mem.indexOf(u8, source[start .. start + relative], key).?;
            try sink.add(key_start, key_start + key.len, .property);
        }
    } else if (targetColon(source[start..end])) |relative| {
        const target = std.mem.trim(u8, source[start .. start + relative], " \t");
        if (target.len > 0) {
            const target_start = start + std.mem.indexOf(u8, source[start .. start + relative], target).?;
            try sink.add(target_start, target_start + target.len, .label);
        }
    }
}

fn scanVariable(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    var cursor = start + 1;
    if (cursor < end and (source[cursor] == '(' or source[cursor] == '{')) {
        const close: u8 = if (source[cursor] == '(') ')' else '}';
        cursor += 1;
        while (cursor < end and source[cursor] != close) cursor += 1;
        if (cursor < end) cursor += 1;
    } else if (cursor < end) {
        cursor += 1;
    }
    try sink.add(start, cursor, .variable);
    return cursor;
}

fn scanQuoted(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!usize {
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

fn scanOperator(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    var cursor = start + 1;
    while (cursor < end and std.mem.indexOfScalar(u8, ":=+?!", source[cursor]) != null) cursor += 1;
    try sink.add(start, cursor, .operator);
    return cursor;
}

fn assignmentOperator(line: []const u8) ?usize {
    var index: usize = 0;
    while (index < line.len) : (index += 1) {
        if (line[index] == '=') return if (index > 0 and std.mem.indexOfScalar(u8, ":+?!", line[index - 1]) != null) index - 1 else index;
    }
    return null;
}

fn targetColon(line: []const u8) ?usize {
    for (line, 0..) |byte, index| if (byte == ':' and (index + 1 == line.len or line[index + 1] != '=')) return index;
    return null;
}

fn isNameByte(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '-';
}

fn isDirective(word: []const u8) bool {
    const words = [_][]const u8{ "define", "else", "endef", "endif", "export", "if", "ifdef", "ifeq", "ifndef", "ifneq", "include", "override", "private", "sinclude", "undefine", "unexport", "vpath" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
