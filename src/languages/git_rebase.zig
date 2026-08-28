const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const bash = @import("bash.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "git-rebase",
    .display_name = "Git rebase",
    .kind = .composed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        try scanLine(source, line_start, line_end, sink);
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn scanLine(source: []const u8, start: usize, end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var cursor = start;
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (cursor == end) return;
    if (source[cursor] == '#') {
        try sink.add(cursor, end, .comment);
        return;
    }
    const command_start = cursor;
    while (cursor < end and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
    const command = source[command_start..cursor];
    if (!isCommand(command)) return;
    try sink.add(command_start, cursor, .keyword);
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (isExec(command)) {
        try composition.highlightEmbedded(source, .{ .start = cursor, .end = end }, bash.backend, sink);
        return;
    }
    if (cursor == end) return;
    const argument_start = cursor;
    while (cursor < end and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
    try sink.add(argument_start, cursor, if (usesLabel(command)) .label else .constant);
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (cursor < end) try sink.add(cursor, end, .string);
}

fn isExec(word: []const u8) bool {
    return std.mem.eql(u8, word, "exec") or std.mem.eql(u8, word, "x");
}

fn usesLabel(word: []const u8) bool {
    return std.mem.eql(u8, word, "label") or std.mem.eql(u8, word, "l") or std.mem.eql(u8, word, "reset") or std.mem.eql(u8, word, "t");
}

fn isCommand(word: []const u8) bool {
    const commands = [_][]const u8{ "pick", "p", "reword", "r", "edit", "e", "squash", "s", "fixup", "f", "exec", "x", "break", "b", "drop", "d", "label", "l", "reset", "t", "merge", "m", "update-ref", "u" };
    for (commands) |command| if (std.mem.eql(u8, word, command)) return true;
    return false;
}
