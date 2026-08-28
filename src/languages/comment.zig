const std = @import("std");
const api = @import("../backend.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "comment",
    .display_name = "Comment tags",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var index: usize = 0;
    while (index < source.len) {
        if (urlEnd(source, index)) |end| {
            try sink.add(index, end, .string);
            try sink.add(index, end, .markup_link);
            index = end;
        } else if (source[index] == '#' and index + 1 < source.len and std.ascii.isDigit(source[index + 1])) {
            const start = index;
            index += 2;
            while (index < source.len and std.ascii.isDigit(source[index])) index += 1;
            try sink.add(start, index, .number);
        } else if (isWordStart(source[index])) {
            const start = index;
            index += 1;
            while (index < source.len and isWordContinue(source[index])) index += 1;
            if (isTag(source[start..index])) {
                try sink.add(start, index, .special);
                index = try scanTagSuffix(source, index, sink);
            }
        } else {
            index += 1;
        }
    }
}

fn scanTagSuffix(source: []const u8, start: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    var index = start;
    if (index < source.len and source[index] == '(') {
        try sink.add(index, index + 1, .punctuation);
        index += 1;
        const user_start = index;
        while (index < source.len and source[index] != ')' and source[index] != '\n') index += 1;
        if (user_start < index) try sink.add(user_start, index, .constant);
        if (index < source.len and source[index] == ')') {
            try sink.add(index, index + 1, .punctuation);
            index += 1;
        }
    }
    if (index < source.len and source[index] == ':') {
        try sink.add(index, index + 1, .punctuation);
        index += 1;
    }
    return index;
}

fn urlEnd(source: []const u8, start: usize) ?usize {
    if (!(std.mem.startsWith(u8, source[start..], "https://") or
        std.mem.startsWith(u8, source[start..], "http://"))) return null;
    if (start != 0 and !std.ascii.isWhitespace(source[start - 1])) return null;
    var end = start;
    while (end < source.len and !std.ascii.isWhitespace(source[end])) end += 1;
    return end;
}

fn isTag(word: []const u8) bool {
    const tags = [_][]const u8{
        "BUG",  "DOCS", "ERROR", "FIX",  "FIXME",   "HACK", "INFO", "NOTE",
        "PERF", "TEST", "TODO",  "WARN", "WARNING", "WIP",  "XXX",
    };
    for (tags) |tag| if (std.mem.eql(u8, word, tag)) return true;
    return false;
}

fn isWordStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isWordContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
