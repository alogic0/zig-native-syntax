const std = @import("std");
const api = @import("../backend.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "jsdoc", .display_name = "JSDoc", .kind = .lexical }, highlight);
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
            while (i < s.len and std.ascii.isAlphabetic(s[i])) i += 1;
            try k.add(at, i, .attribute);
        } else if (s[i] == '{') {
            const at = i;
            i += 1;
            while (i < s.len and s[i] != '}' and s[i] != '\n') i += 1;
            if (i < s.len and s[i] == '}') i += 1;
            try k.add(at, i, .type);
        } else if (s[i] == '`') {
            const at = i;
            i += 1;
            while (i < s.len and s[i] != '`' and s[i] != '\n') i += 1;
            if (i < s.len and s[i] == '`') i += 1;
            try k.add(at, i, .markup_code);
        } else i += 1;
    }
}
