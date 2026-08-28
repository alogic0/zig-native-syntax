const std = @import("std");
const api = @import("../backend.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "rst",
    .display_name = "reStructuredText",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var start: usize = 0;
    var previous: ?struct { start: usize, end: usize } = null;
    while (start < source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        const line = source[start..end];
        const indent = skipIndent(line);
        const trimmed = line[indent..];

        if (adornment(trimmed) and previous != null) {
            const heading = previous.?;
            try sink.add(heading.start, heading.end, .markup_heading);
            try sink.add(start + indent, end, .markup_heading);
        } else if (std.mem.startsWith(u8, trimmed, ".. ")) {
            if (directiveEnd(trimmed)) |directive_end| {
                try sink.add(start + indent, start + indent + directive_end, .attribute);
            } else {
                try sink.add(start + indent, end, .comment);
            }
        } else if (optionEnd(trimmed)) |option_end| {
            try sink.add(start + indent, start + indent + option_end, .property);
        } else if (listEnd(trimmed)) |list_end| {
            try sink.add(start + indent, start + indent + list_end, .markup_list);
        }
        try scanInline(source, sink, start, end);
        previous = if (trimmed.len == 0) null else .{ .start = start + indent, .end = end };
        start = if (end < source.len) end + 1 else end;
    }
}

fn directiveEnd(line: []const u8) ?usize {
    var cursor: usize = 3;
    while (cursor < line.len and (std.ascii.isAlphanumeric(line[cursor]) or line[cursor] == '-' or line[cursor] == '_')) cursor += 1;
    if (cursor == 3 or cursor + 1 >= line.len or !std.mem.eql(u8, line[cursor .. cursor + 2], "::")) return null;
    return cursor + 2;
}

fn optionEnd(line: []const u8) ?usize {
    if (line.len < 3 or line[0] != ':') return null;
    const close = std.mem.indexOfScalarPos(u8, line, 1, ':') orelse return null;
    if (close == 1) return null;
    return close + 1;
}

fn listEnd(line: []const u8) ?usize {
    if (line.len >= 2 and (line[0] == '-' or line[0] == '+' or line[0] == '*') and std.ascii.isWhitespace(line[1])) return 1;
    var cursor: usize = 0;
    while (cursor < line.len and std.ascii.isDigit(line[cursor])) cursor += 1;
    if (cursor > 0 and cursor + 1 < line.len and line[cursor] == '.' and std.ascii.isWhitespace(line[cursor + 1])) return cursor + 1;
    return null;
}

fn adornment(line: []const u8) bool {
    if (line.len < 3 or std.mem.indexOfScalar(u8, "=-~^\"'`:+*#_", line[0]) == null) return false;
    for (line[1..]) |byte| if (byte != line[0]) return false;
    return true;
}

fn scanInline(source: []const u8, sink: *api.CaptureSink, start: usize, end: usize) api.HighlightError!void {
    var cursor = start;
    while (cursor < end) {
        if (cursor + 1 < end and source[cursor] == '`' and source[cursor + 1] == '`') {
            const close = std.mem.indexOfPos(u8, source[0..end], cursor + 2, "``") orelse end - 2;
            const capture_end = @min(end, close + 2);
            try sink.add(cursor, capture_end, .markup_code);
            cursor = capture_end;
        } else if (source[cursor] == '`') {
            const close = std.mem.indexOfScalarPos(u8, source, cursor + 1, '`') orelse {
                cursor += 1;
                continue;
            };
            var capture_end = close + 1;
            if (capture_end < end and source[capture_end] == '_') capture_end += 1;
            try sink.add(cursor, capture_end, .markup_link);
            cursor = capture_end;
        } else if (source[cursor] == ':') {
            if (optionEnd(source[cursor..end])) |role_end| {
                if (cursor + role_end < end and source[cursor + role_end] == '`') {
                    const close = std.mem.indexOfScalarPos(u8, source, cursor + role_end + 1, '`') orelse end - 1;
                    try sink.add(cursor, @min(end, close + 1), .markup_link);
                    cursor = @min(end, close + 1);
                } else cursor += 1;
            } else cursor += 1;
        } else cursor += 1;
    }
}

fn skipIndent(line: []const u8) usize {
    var cursor: usize = 0;
    while (cursor < line.len and (line[cursor] == ' ' or line[cursor] == '\t')) cursor += 1;
    return cursor;
}
