const std = @import("std");
const api = @import("../backend.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "gitcommit",
    .display_name = "Git commit",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var line_start: usize = 0;
    var first_content = true;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        const line = source[line_start..line_end];
        if (line.len > 0 and line[0] == '#') {
            try sink.add(line_start, line_end, if (std.mem.indexOf(u8, line, ">8") != null) .special else .comment);
        } else if (first_content and line.len > 0) {
            try sink.add(line_start, line_end, .markup_heading);
            try scanConventionalPrefix(source, line_start, line_end, sink);
            first_content = false;
        } else if (statusPrefix(line)) |prefix_len| {
            try sink.add(line_start, line_start + prefix_len, .label);
            var path_start = line_start + prefix_len;
            while (path_start < line_end and std.ascii.isWhitespace(source[path_start])) path_start += 1;
            if (path_start < line_end) try sink.add(path_start, line_end, .string);
        }
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn scanConventionalPrefix(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor = start;
    while (cursor < end and (std.ascii.isAlphabetic(source[cursor]) or source[cursor] == '-')) cursor += 1;
    if (cursor == start) return;
    if (cursor < end and source[cursor] == '(') {
        try sink.add(start, cursor, .keyword);
        const label_start = cursor + 1;
        cursor += 1;
        while (cursor < end and source[cursor] != ')') cursor += 1;
        if (label_start < cursor) try sink.add(label_start, cursor, .label);
        if (cursor < end) {
            try sink.add(cursor, cursor + 1, .punctuation);
            cursor += 1;
        }
    }
    if (cursor < end and source[cursor] == '!') {
        try sink.add(cursor, cursor + 1, .operator);
        cursor += 1;
    }
    if (cursor < end and source[cursor] == ':') {
        if (source[start] != 0 and std.mem.indexOfScalar(u8, source[start..cursor], '(') == null) try sink.add(start, cursor, .keyword);
        try sink.add(cursor, cursor + 1, .punctuation);
    }
}

fn statusPrefix(line: []const u8) ?usize {
    const prefixes = [_][]const u8{ "modified:", "new file:", "deleted:", "renamed:" };
    var indent: usize = 0;
    while (indent < line.len and (line[indent] == ' ' or line[indent] == '\t')) indent += 1;
    const trimmed = line[indent..];
    for (prefixes) |prefix| if (std.mem.startsWith(u8, trimmed, prefix)) return line.len - trimmed.len + prefix.len;
    return null;
}
