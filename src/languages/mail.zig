const std = @import("std");
const api = @import("../backend.zig");
pub const backend: api.Backend = .init(.{
    .canonical_name = "mail",
    .display_name = "E-mail",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);
fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var start: usize = 0;
    var in_headers = true;
    while (start < source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        const line = source[start..end];
        if (line.len == 0) {
            in_headers = false;
        } else if (in_headers) {
            if (headerEnd(line)) |header_end| {
                try sink.add(start, start + header_end, .property);
                try scanLinks(source, sink, start + header_end, end);
            } else if (line[0] == ' ' or line[0] == '\t') {
                try scanLinks(source, sink, start, end);
            } else {
                in_headers = false;
            }
        }
        if (!in_headers) {
            const quote_end = quotePrefixEnd(line);
            if (quote_end > 0) {
                try sink.add(start, end, .markup_quote);
                try sink.add(start, start + quote_end, .punctuation);
            } else if (std.mem.eql(u8, line, "-- ")) {
                try sink.add(start, end, .special);
            }
            try scanLinks(source, sink, start + quote_end, end);
        }
        start = if (end < source.len) end + 1 else end;
    }
}

fn headerEnd(line: []const u8) ?usize {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    if (colon == 0) return null;
    for (line[0..colon]) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-') return null;
    return colon + 1;
}

fn quotePrefixEnd(line: []const u8) usize {
    var cursor: usize = 0;
    while (cursor < line.len and line[cursor] == '>') {
        cursor += 1;
        if (cursor < line.len and line[cursor] == ' ') cursor += 1;
    }
    return cursor;
}

fn scanLinks(source: []const u8, sink: *api.CaptureSink, start: usize, end: usize) api.HighlightError!void {
    var cursor = start;
    while (cursor < end) {
        if (std.mem.startsWith(u8, source[cursor..end], "http://") or std.mem.startsWith(u8, source[cursor..end], "https://")) {
            const link_start = cursor;
            while (cursor < end and !std.ascii.isWhitespace(source[cursor]) and std.mem.indexOfScalar(u8, ")]>\"'", source[cursor]) == null) cursor += 1;
            try sink.add(link_start, cursor, .markup_link);
        } else if (source[cursor] == '@') {
            var local = cursor;
            while (local > start and isAddressByte(source[local - 1])) local -= 1;
            var domain = cursor + 1;
            while (domain < end and isAddressByte(source[domain])) domain += 1;
            if (local < cursor and cursor + 1 < domain) try sink.add(local, domain, .markup_link);
            cursor = domain;
        } else cursor += validUtf8Length(source[cursor..end]);
    }
}

fn isAddressByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or std.mem.indexOfScalar(u8, ".!#$%&'*+/=?^_`{|}~-", byte) != null;
}
fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
