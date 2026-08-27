const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const Span = @import("../capture.zig").Span;
const bash = @import("bash.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "shell-session",
    .display_name = "Shell session",
    .kind = .composed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        if (commandRegion(source[line_start..line_end], line_start)) |region| {
            try sink.add(line_start, region.start, .special);
            try composition.highlightEmbedded(source, region, bash.backend, sink);
        }
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn commandRegion(line: []const u8, offset: usize) ?Span {
    if (std.mem.startsWith(u8, line, "$ ") or std.mem.startsWith(u8, line, "> ") or std.mem.startsWith(u8, line, "% ")) {
        return .{ .start = offset + 2, .end = offset + line.len };
    }

    // Conventional user@host:path$ prompts are accepted only when the marker
    // is followed by a space, keeping ordinary output containing '$' plain.
    if (std.mem.indexOf(u8, line, "$ ")) |marker| {
        if (marker > 0 and std.mem.indexOfScalar(u8, line[0..marker], '@') != null) {
            return .{ .start = offset + marker + 2, .end = offset + line.len };
        }
    }
    return null;
}
