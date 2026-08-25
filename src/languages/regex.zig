const std = @import("std");
const api = @import("../backend.zig");
const utf8 = @import("../utf8.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "regex", .display_name = "Regular expression", .kind = .lexical }, highlight);
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
            while (i < s.len and s[i] != ']') {
                if (s[i] == '\\') i = utf8.escapedSequenceEnd(s, i, s.len) else i += 1;
            }
            if (i < s.len) i += 1;
            try k.add(at, i, .string);
        },
        '(', ')' => {
            try k.add(i, i + 1, .punctuation);
            i += 1;
        },
        '*', '+', '?', '|', '{', '}' => {
            try k.add(i, i + 1, .operator);
            i += 1;
        },
        '^', '$', '.' => {
            try k.add(i, i + 1, .special);
            i += 1;
        },
        else => i += 1,
    };
}
