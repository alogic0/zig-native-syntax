const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "diff",
    .display_name = "Diff",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        const line = source[line_start..line_end];

        if (std.mem.startsWith(u8, line, "@@")) {
            const marker_end = if (std.mem.indexOfPos(u8, line, 2, "@@")) |end|
                line_start + end + 2
            else
                line_end;
            try sink.add(line_start, marker_end, .special);
        } else if (std.mem.startsWith(u8, line, "--- ") or
            std.mem.startsWith(u8, line, "+++ "))
        {
            try sink.add(line_start, line_start + 3, .operator);
            if (line.len > 4) try sink.add(line_start + 4, line_end, .label);
        } else if (startsMetadata(line)) {
            const keyword_end = std.mem.indexOfScalar(u8, line, ' ') orelse line.len;
            try sink.add(line_start, line_start + keyword_end, .keyword);
        } else if (line.len > 0 and (line[0] == '+' or line[0] == '-')) {
            try sink.add(line_start, line_start + 1, .operator);
        } else if (std.mem.startsWith(u8, line, "\\ No newline at end of file")) {
            try sink.add(line_start, line_end, .comment);
        }

        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn startsMetadata(line: []const u8) bool {
    const prefixes = [_][]const u8{
        "diff ",
        "index ",
        "new file mode ",
        "deleted file mode ",
        "old mode ",
        "new mode ",
        "similarity index ",
        "rename from ",
        "rename to ",
        "Binary files ",
    };
    for (prefixes) |prefix| {
        if (std.mem.startsWith(u8, line, prefix)) return true;
    }
    return false;
}
