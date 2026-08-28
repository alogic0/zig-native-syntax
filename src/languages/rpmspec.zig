const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const rpmbash = @import("rpmbash.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "rpmspec",
    .display_name = "RPM spec",
    .kind = .composed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var start: usize = 0;
    var section: Section = .preamble;
    while (start < source.len) {
        const end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
        const line = source[start..end];
        const indent = skipSpaces(line);

        if (indent < line.len and line[indent] == '%') {
            if (sectionDirective(line[indent..])) |directive| {
                try sink.add(start + indent, start + indent + directive.end, .keyword);
                section = directive.section;
                try scanMacros(source, sink, start + indent + directive.end, end);
                start = if (end < source.len) end + 1 else end;
                continue;
            }
        }

        if (section == .bash and indent < line.len) {
            try composition.highlightEmbedded(source, .{ .start = start, .end = end }, rpmbash.backend, sink);
        } else if (indent < line.len and line[indent] == '#') {
            try sink.add(start + indent, end, .comment);
        } else if (section == .preamble) {
            if (headerEnd(line[indent..])) |header_end| {
                try sink.add(start + indent, start + indent + header_end, .property);
                const value_start = start + indent + header_end;
                try scanNumbers(source, sink, value_start, end);
            }
        } else if (section == .changelog and indent < line.len and line[indent] == '*') {
            try sink.add(start + indent, start + indent + 1, .markup_list);
        }
        try scanMacros(source, sink, start, end);
        start = if (end < source.len) end + 1 else end;
    }
}

const Section = enum { preamble, text, files, changelog, bash };
const Directive = struct { end: usize, section: Section };

fn sectionDirective(line: []const u8) ?Directive {
    if (line.len < 2 or line[0] != '%' or line[1] == '{') return null;
    var end: usize = 1;
    while (end < line.len and (std.ascii.isAlphabetic(line[end]) or std.ascii.isDigit(line[end]) or line[end] == '_')) end += 1;
    const word = line[1..end];
    if (isBashSection(word)) return .{ .end = end, .section = .bash };
    if (std.ascii.eqlIgnoreCase(word, "description") or std.ascii.eqlIgnoreCase(word, "package")) return .{ .end = end, .section = .text };
    if (std.ascii.eqlIgnoreCase(word, "files")) return .{ .end = end, .section = .files };
    if (std.ascii.eqlIgnoreCase(word, "changelog")) return .{ .end = end, .section = .changelog };
    return null;
}

fn isBashSection(word: []const u8) bool {
    const sections = [_][]const u8{ "prep", "build", "install", "check", "clean", "pre", "post", "preun", "postun", "pretrans", "posttrans", "trigger", "triggerin", "triggerun", "triggerpostun" };
    for (sections) |section| if (std.ascii.eqlIgnoreCase(word, section)) return true;
    return false;
}

fn headerEnd(line: []const u8) ?usize {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return null;
    if (colon == 0) return null;
    for (line[0..colon]) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-' and byte != '_') return null;
    return colon + 1;
}

fn scanMacros(source: []const u8, sink: *api.CaptureSink, start: usize, end: usize) api.HighlightError!void {
    var cursor = start;
    while (cursor < end) {
        if (source[cursor] != '%' or cursor + 1 >= end) {
            cursor += validUtf8Length(source[cursor..end]);
            continue;
        }
        const macro_start = cursor;
        cursor += 1;
        if (source[cursor] == '%') {
            cursor += 1;
        } else if (source[cursor] == '{') {
            cursor += 1;
            var depth: usize = 1;
            while (cursor < end and depth > 0) : (cursor += 1) {
                if (source[cursor] == '{') depth += 1;
                if (source[cursor] == '}') depth -= 1;
            }
        } else {
            while (cursor < end and (std.ascii.isAlphanumeric(source[cursor]) or source[cursor] == '_')) cursor += 1;
        }
        if (cursor > macro_start + 1) try sink.add(macro_start, cursor, .macro);
    }
}

fn scanNumbers(source: []const u8, sink: *api.CaptureSink, start: usize, end: usize) api.HighlightError!void {
    var cursor = start;
    while (cursor < end) {
        if (std.ascii.isDigit(source[cursor])) {
            const number_start = cursor;
            while (cursor < end and (std.ascii.isDigit(source[cursor]) or source[cursor] == '.')) cursor += 1;
            try sink.add(number_start, cursor, .number);
        } else cursor += validUtf8Length(source[cursor..end]);
    }
}

fn skipSpaces(line: []const u8) usize {
    var cursor: usize = 0;
    while (cursor < line.len and (line[cursor] == ' ' or line[cursor] == '\t')) cursor += 1;
    return cursor;
}
fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
