const std = @import("std");
const api = @import("../backend.zig");
const utf8 = @import("../utf8.zig");
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;
pub const backend: api.Backend = .init(.{
    .canonical_name = "regex",
    .display_name = "Regular expression",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    var i: usize = 0;
    while (i < s.len) switch (s[i]) {
        '\\' => {
            const e = utf8.escapedSequenceEnd(s, i, s.len);
            try k.add(i, e, .escape);
            i = e;
        },
        '[' => {
            const at = i;
            i += 1;
            if (i < s.len and s[i] == '^') i += 1;
            while (i < s.len and s[i] != ']') {
                if (s[i] == '\\') {
                    const escape_start = i;
                    i = utf8.escapedSequenceEnd(s, i, s.len);
                    try k.add(escape_start, i, .escape);
                } else {
                    i += validUtf8Length(s[i..]);
                }
            }
            if (i < s.len) i += 1;
            try k.add(at, i, .string);
        },
        '(' => {
            const at = i;
            i += 1;
            if (i < s.len and s[i] == '?') {
                i += 1;
                if (i < s.len and (s[i] == '<' or s[i] == '\'')) {
                    const close: u8 = if (s[i] == '<') '>' else '\'';
                    i += 1;
                    const name_start = i;
                    while (i < s.len and s[i] != close and s[i] != '\n') i += 1;
                    if (name_start < i) try k.add(name_start, i, .label);
                    if (i < s.len and s[i] == close) i += 1;
                } else {
                    while (i < s.len and (std.ascii.isAlphabetic(s[i]) or s[i] == '-' or s[i] == ':')) i += 1;
                }
                try k.add(at, i, .special);
            } else {
                try k.add(at, i, .punctuation);
            }
        },
        ')' => {
            try k.add(i, i + 1, .punctuation);
            i += 1;
        },
        '{' => {
            const at = i;
            i += 1;
            while (i < s.len and (std.ascii.isDigit(s[i]) or s[i] == ',' or std.ascii.isWhitespace(s[i]))) i += 1;
            if (i < s.len and s[i] == '}') i += 1;
            if (i < s.len and (s[i] == '?' or s[i] == '+')) i += 1;
            try k.add(at, i, .operator);
        },
        '*', '+', '?' => {
            const at = i;
            i += 1;
            if (i < s.len and (s[i] == '?' or s[i] == '+')) i += 1;
            try k.add(at, i, .operator);
        },
        '|', '}' => {
            try k.add(i, i + 1, .operator);
            i += 1;
        },
        '^', '$', '.' => {
            try k.add(i, i + 1, .special);
            i += 1;
        },
        else => i += validUtf8Length(s[i..]),
    };
}
