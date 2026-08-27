const std = @import("std");
const api = @import("../backend.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "jsdoc",
    .display_name = "JSDoc",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    if (s.len > 0) {
        try k.add(0, s.len, .comment);
        try k.add(0, s.len, .documentation);
    }
    var i: usize = 0;
    while (i < s.len) {
        if (s[i] == '@') {
            const at = i;
            i += 1;
            while (i < s.len and (std.ascii.isAlphanumeric(s[i]) or s[i] == '_' or s[i] == '-')) i += 1;
            try k.add(at, i, .attribute);
        } else if (s[i] == '{') {
            const at = i;
            i += 1;
            if (i < s.len and s[i] == '@') {
                while (i < s.len and s[i] != '}' and s[i] != '\n') i += 1;
                if (i < s.len and s[i] == '}') i += 1;
                try k.add(at, i, .markup_link);
                continue;
            }
            var depth: usize = 1;
            while (i < s.len and depth > 0 and s[i] != '\n') : (i += 1) {
                if (s[i] == '{') depth += 1;
                if (s[i] == '}') depth -= 1;
            }
            try k.add(at, i, .type);
            const name_start = skipSpaces(s, i);
            var name_end = name_start;
            if (name_end < s.len and s[name_end] == '[') {
                var bracket_depth: usize = 1;
                name_end += 1;
                while (name_end < s.len and bracket_depth > 0 and s[name_end] != '\n') : (name_end += 1) {
                    if (s[name_end] == '[') bracket_depth += 1;
                    if (s[name_end] == ']') bracket_depth -= 1;
                }
            } else {
                while (name_end < s.len and (std.ascii.isAlphanumeric(s[name_end]) or s[name_end] == '_' or s[name_end] == '.' or s[name_end] == '-')) name_end += 1;
            }
            if (name_start < name_end) try k.add(name_start, name_end, .parameter);
        } else if (s[i] == '`') {
            const at = i;
            i += 1;
            while (i < s.len and s[i] != '`' and s[i] != '\n') i += 1;
            if (i < s.len and s[i] == '`') i += 1;
            try k.add(at, i, .markup_code);
        } else i += 1;
    }
}

fn skipSpaces(source: []const u8, start: usize) usize {
    var cursor = start;
    while (cursor < source.len and (source[cursor] == ' ' or source[cursor] == '\t' or source[cursor] == '*')) cursor += 1;
    return cursor;
}
