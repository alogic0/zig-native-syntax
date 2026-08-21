const std = @import("std");
const api = @import("../backend.zig");
pub fn highlight(source: []const u8, sink: *api.CaptureSink, astro: bool) api.HighlightError!void {
    var i: usize = 0;
    if (astro and std.mem.startsWith(u8, source, "---")) {
        const end = std.mem.indexOfPos(u8, source, 3, "\n---") orelse source.len;
        try sink.add(0, @min(3, source.len), .special);
        if (end > 3) try sink.add(3, end, .embedded);
        i = end;
        if (end < source.len) {
            const marker_end = @min(end + 4, source.len);
            try sink.add(end + 1, marker_end, .special);
            i = marker_end;
        }
    }
    while (i < source.len) {
        if (std.mem.startsWith(u8, source[i..], "<!--")) {
            const close = std.mem.indexOfPos(u8, source, i + 4, "-->");
            const end = if (close) |at| at + 3 else source.len;
            try sink.add(i, end, .comment);
            i = end;
        } else if (i + 1 < source.len and source[i] == '{' and source[i + 1] == '{') {
            const close = std.mem.indexOfPos(u8, source, i + 2, "}}");
            const end = if (close) |at| at + 2 else source.len;
            try sink.add(i, end, .embedded);
            i = end;
        } else if (source[i] == '<') i = try scanTag(source, i, sink) else i += 1;
    }
}
fn scanTag(s: []const u8, start: usize, k: *api.CaptureSink) api.HighlightError!usize {
    var i = start;
    try k.add(i, i + 1, .punctuation);
    i += 1;
    if (i < s.len and s[i] == '/') {
        try k.add(i, i + 1, .punctuation);
        i += 1;
    }
    const name = i;
    while (i < s.len and (std.ascii.isAlphanumeric(s[i]) or s[i] == '-' or s[i] == ':' or s[i] == '.')) i += 1;
    if (i > name) try k.add(name, i, .tag);
    while (i < s.len and s[i] != '>' and s[i] != '\n') {
        if (s[i] == '"' or s[i] == '\'') {
            const q = s[i];
            const at = i;
            i += 1;
            while (i < s.len and s[i] != q and s[i] != '\n') i += 1;
            if (i < s.len and s[i] == q) i += 1;
            try k.add(at, i, .string);
        } else if (std.ascii.isAlphabetic(s[i]) or s[i] == '@' or s[i] == ':' or s[i] == '#') {
            const at = i;
            i += 1;
            while (i < s.len and (std.ascii.isAlphanumeric(s[i]) or s[i] == '-' or s[i] == ':' or s[i] == '@')) i += 1;
            try k.add(at, i, .attribute);
        } else if (s[i] == '=' or s[i] == '/') {
            try k.add(i, i + 1, .operator);
            i += 1;
        } else i += 1;
    }
    if (i < s.len and s[i] == '>') {
        try k.add(i, i + 1, .punctuation);
        i += 1;
    }
    return i;
}
