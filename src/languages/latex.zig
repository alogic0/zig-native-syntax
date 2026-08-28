const std = @import("std");
const api = @import("../backend.zig");
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;
pub const backend: api.Backend = .init(.{
    .canonical_name = "latex",
    .display_name = "LaTeX",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var i: usize = 0;
    while (i < source.len) switch (source[i]) {
        '%' => {
            const start = i;
            i = std.mem.indexOfScalarPos(u8, source, i, '\n') orelse source.len;
            try sink.add(start, i, .comment);
        },
        '\\' => {
            const start = i;
            i += 1;
            if (i < source.len and std.ascii.isAlphabetic(source[i])) {
                while (i < source.len and std.ascii.isAlphabetic(source[i])) i += 1;
                if (i < source.len and source[i] == '*') i += 1;
                try sink.add(start, i, .keyword);
                const command = source[start + 1 .. i - @intFromBool(source[i - 1] == '*')];
                if (std.mem.eql(u8, command, "begin") or std.mem.eql(u8, command, "end")) {
                    if (nextGroup(source, i)) |group| try sink.add(group.start, group.end, .tag);
                }
            } else {
                i += validUtf8Length(source[i..]);
                try sink.add(start, i, .escape);
            }
        },
        '$' => {
            const start = i;
            const display = i + 1 < source.len and source[i + 1] == '$';
            i += if (display) 2 else 1;
            const close = if (display) "$$" else "$";
            i = if (std.mem.indexOfPos(u8, source, i, close)) |end| end + close.len else source.len;
            try sink.add(start, i, .markup_code);
        },
        '{', '}', '[', ']', '&' => {
            try sink.add(i, i + 1, .punctuation);
            i += 1;
        },
        '#', '^', '_' => {
            try sink.add(i, i + 1, .operator);
            i += 1;
        },
        '0'...'9' => {
            const start = i;
            while (i < source.len and (std.ascii.isDigit(source[i]) or source[i] == '.')) i += 1;
            try sink.add(start, i, .number);
        },
        else => i += validUtf8Length(source[i..]),
    };
}

const Group = struct { start: usize, end: usize };
fn nextGroup(source: []const u8, after: usize) ?Group {
    var cursor = after;
    while (cursor < source.len and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    if (cursor >= source.len or source[cursor] != '{') return null;
    const start = cursor + 1;
    cursor = std.mem.indexOfScalarPos(u8, source, start, '}') orelse return null;
    return .{ .start = start, .end = cursor };
}
