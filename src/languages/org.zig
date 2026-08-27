const std = @import("std");
const api = @import("../backend.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "org",
    .display_name = "Org Mode",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var start: usize = 0;
    var source_block = false;
    while (start < source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        const line = source[start..end];
        const trimmed_at = skipIndent(line);
        const trimmed = line[trimmed_at..];

        if (directive(trimmed)) |item| {
            try sink.add(start + trimmed_at, start + trimmed_at + item.end, .attribute);
            if (std.ascii.eqlIgnoreCase(item.name, "BEGIN_SRC")) {
                source_block = true;
                const language_start = skipSpaces(trimmed, item.end);
                var language_end = language_start;
                while (language_end < trimmed.len and !std.ascii.isWhitespace(trimmed[language_end])) language_end += 1;
                if (language_start < language_end) try sink.add(start + trimmed_at + language_start, start + trimmed_at + language_end, .tag);
            } else if (std.ascii.eqlIgnoreCase(item.name, "END_SRC")) {
                source_block = false;
            }
        } else if (source_block) {
            if (start < end) try sink.add(start, end, .embedded);
        } else if (trimmed.len > 1 and trimmed[0] == '#' and std.ascii.isWhitespace(trimmed[1])) {
            try sink.add(start + trimmed_at, end, .comment);
        } else if (headingEnd(trimmed)) |marker_end| {
            try sink.add(start + trimmed_at, end, .markup_heading);
            const word_start = skipSpaces(trimmed, marker_end);
            const word_end = wordEnd(trimmed, word_start);
            if (isTodo(trimmed[word_start..word_end])) try sink.add(start + trimmed_at + word_start, start + trimmed_at + word_end, .keyword);
        } else if (listMarkerEnd(trimmed)) |marker_end| {
            try sink.add(start + trimmed_at, start + trimmed_at + marker_end, .markup_list);
        } else if (drawerOrProperty(trimmed)) |property_end| {
            try sink.add(start + trimmed_at, start + trimmed_at + property_end, .property);
        }
        if (!source_block) try scanLinks(source, sink, start, end);
        start = if (end < source.len) end + 1 else end;
    }
}

const Directive = struct { name: []const u8, end: usize };
fn directive(line: []const u8) ?Directive {
    if (!std.mem.startsWith(u8, line, "#+")) return null;
    var end: usize = 2;
    while (end < line.len and (std.ascii.isAlphanumeric(line[end]) or line[end] == '_')) end += 1;
    if (end == 2) return null;
    const name_end = end;
    if (end < line.len and line[end] == ':') end += 1 else if (end < line.len and !std.ascii.isWhitespace(line[end])) return null;
    return .{ .name = line[2..name_end], .end = end };
}

fn headingEnd(line: []const u8) ?usize {
    var end: usize = 0;
    while (end < line.len and line[end] == '*') end += 1;
    if (end == 0 or end >= line.len or !std.ascii.isWhitespace(line[end])) return null;
    return end;
}

fn listMarkerEnd(line: []const u8) ?usize {
    if (line.len >= 2 and (line[0] == '-' or line[0] == '+') and std.ascii.isWhitespace(line[1])) return 1;
    var end: usize = 0;
    while (end < line.len and std.ascii.isDigit(line[end])) end += 1;
    if (end > 0 and end + 1 < line.len and (line[end] == '.' or line[end] == ')') and std.ascii.isWhitespace(line[end + 1])) return end + 1;
    return null;
}

fn drawerOrProperty(line: []const u8) ?usize {
    if (line.len < 3 or line[0] != ':') return null;
    const close = std.mem.indexOfScalarPos(u8, line, 1, ':') orelse return null;
    for (line[1..close]) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '-') return null;
    return close + 1;
}

fn scanLinks(source: []const u8, sink: *api.CaptureSink, start: usize, end: usize) api.HighlightError!void {
    var cursor = start;
    while (std.mem.indexOfPos(u8, source[0..end], cursor, "[[")) |link_start| {
        const close = std.mem.indexOfPos(u8, source[0..end], link_start + 2, "]]") orelse {
            try sink.add(link_start, end, .markup_link);
            return;
        };
        try sink.add(link_start, close + 2, .markup_link);
        cursor = close + 2;
    }
}

fn skipIndent(line: []const u8) usize {
    return skipSpaces(line, 0);
}
fn skipSpaces(line: []const u8, from: usize) usize {
    var cursor = from;
    while (cursor < line.len and (line[cursor] == ' ' or line[cursor] == '\t')) cursor += 1;
    return cursor;
}
fn wordEnd(line: []const u8, from: usize) usize {
    var cursor = from;
    while (cursor < line.len and !std.ascii.isWhitespace(line[cursor])) cursor += 1;
    return cursor;
}
fn isTodo(word: []const u8) bool {
    return std.mem.eql(u8, word, "TODO") or std.mem.eql(u8, word, "DONE") or std.mem.eql(u8, word, "WAITING") or std.mem.eql(u8, word, "CANCELLED");
}
