const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const markup = @import("component_markup.zig");
const javascript = @import("javascript.zig");

pub const backend: api.Backend = .init(.{ .canonical_name = "astro", .display_name = "Astro", .kind = .composed, .support_level = .verified_structural }, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try markup.highlight(source, sink, true);
    var body_start: usize = 0;
    if (std.mem.startsWith(u8, source, "---")) {
        body_start = @min(@as(usize, 3), source.len);
        const close = std.mem.indexOfPos(u8, source, body_start, "\n---") orelse source.len;
        try composition.highlightEmbedded(source, .{ .start = body_start, .end = close }, javascript.backend, sink);
        body_start = if (close < source.len) @min(close + 4, source.len) else source.len;
    }
    try highlightScripts(source, sink, body_start);
    try highlightExpressions(source, sink, body_start);
}

fn highlightScripts(source: []const u8, sink: *api.CaptureSink, from: usize) api.HighlightError!void {
    var cursor = from;
    while (std.mem.indexOfPos(u8, source, cursor, "<script")) |start| {
        const body_start = (std.mem.indexOfScalarPos(u8, source, start + 7, '>') orelse break) + 1;
        const close = std.mem.indexOfPos(u8, source, body_start, "</script>") orelse source.len;
        try composition.highlightEmbedded(source, .{ .start = body_start, .end = close }, javascript.backend, sink);
        cursor = if (close < source.len) close + 9 else source.len;
    }
}

fn highlightExpressions(source: []const u8, sink: *api.CaptureSink, from: usize) api.HighlightError!void {
    var cursor = from;
    while (std.mem.indexOfScalarPos(u8, source, cursor, '{')) |open| {
        const close = std.mem.indexOfScalarPos(u8, source, open + 1, '}') orelse source.len;
        try composition.highlightEmbedded(source, .{ .start = open + 1, .end = close }, javascript.backend, sink);
        cursor = if (close < source.len) close + 1 else source.len;
    }
}
