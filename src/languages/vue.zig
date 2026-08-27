const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const markup = @import("component_markup.zig");
const javascript = @import("javascript.zig");

pub const backend: api.Backend = .init(.{ .canonical_name = "vue", .display_name = "Vue", .kind = .composed, .support_level = .verified_structural }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try markup.highlight(source, sink, false);
    try highlightTags(source, sink, "script", javascript.backend);
    try highlightInterpolations(source, sink);
}

fn highlightTags(source: []const u8, sink: *api.CaptureSink, tag: []const u8, nested: api.Backend) api.HighlightError!void {
    var open_buffer: [32]u8 = undefined;
    var close_buffer: [32]u8 = undefined;
    const open = std.fmt.bufPrint(&open_buffer, "<{s}", .{tag}) catch return;
    const close = std.fmt.bufPrint(&close_buffer, "</{s}>", .{tag}) catch return;
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, source, cursor, open)) |start| {
        const body_start = (std.mem.indexOfScalarPos(u8, source, start + open.len, '>') orelse break) + 1;
        const body_end = std.mem.indexOfPos(u8, source, body_start, close) orelse source.len;
        try composition.highlightEmbedded(source, .{ .start = body_start, .end = body_end }, nested, sink);
        cursor = if (body_end < source.len) body_end + close.len else source.len;
    }
}

fn highlightInterpolations(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, source, cursor, "{{")) |start| {
        const body_start = start + 2;
        const close = std.mem.indexOfPos(u8, source, body_start, "}}") orelse source.len;
        try composition.highlightEmbedded(source, .{ .start = body_start, .end = close }, javascript.backend, sink);
        cursor = if (close < source.len) close + 2 else source.len;
    }
}
