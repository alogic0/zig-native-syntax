const std = @import("std");
const utf8 = @import("../utf8.zig");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "yaml",
    .display_name = "YAML",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var line_start: usize = 0;
    var block_parent_indent: ?usize = null;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        var content_start = line_start;
        while (content_start < line_end and (source[content_start] == ' ' or source[content_start] == '\t')) content_start += 1;
        const indent = content_start - line_start;

        if (block_parent_indent) |parent_indent| {
            if (content_start == line_end or indent > parent_indent) {
                if (content_start < line_end) try sink.add(content_start, line_end, .string);
                line_start = if (line_end < source.len) line_end + 1 else source.len;
                continue;
            }
            block_parent_indent = null;
        }

        if (content_start < line_end) {
            if (source[content_start] == '%') {
                try sink.add(content_start, line_end, .special);
            } else if (isDocumentMarker(source[content_start..line_end])) {
                try sink.add(content_start, line_end, .special);
            } else {
                if (try scanLine(source, content_start, line_end, indent, sink)) {
                    block_parent_indent = indent;
                }
            }
        }
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn scanLine(
    source: []const u8,
    start: usize,
    line_end: usize,
    indent: usize,
    sink: *CaptureSink,
) HighlightError!bool {
    _ = indent;
    var cursor = start;
    var block_scalar = false;
    if (source[cursor] == '-' and (cursor + 1 == line_end or std.ascii.isWhitespace(source[cursor + 1]))) {
        try sink.add(cursor, cursor + 1, .punctuation);
        cursor += 1;
    }

    while (cursor < line_end) switch (source[cursor]) {
        '#' => if (cursor == start or std.ascii.isWhitespace(source[cursor - 1])) {
            try sink.add(cursor, line_end, .comment);
            return block_scalar;
        } else {
            cursor += 1;
        },
        '"', '\'' => cursor = try scanQuoted(source, cursor, line_end, sink),
        '&', '*' => {
            const scope: Scope = if (source[cursor] == '&') .label else .variable;
            const token_start = cursor;
            cursor += 1;
            while (cursor < line_end and isNameByte(source[cursor])) cursor += 1;
            try sink.add(token_start, cursor, scope);
        },
        '!' => {
            const token_start = cursor;
            cursor += 1;
            while (cursor < line_end and !std.ascii.isWhitespace(source[cursor]) and
                std.mem.indexOfScalar(u8, "[]{},", source[cursor]) == null)
            {
                cursor += 1;
            }
            try sink.add(token_start, cursor, .type);
        },
        '[', ']', '{', '}', ',' => {
            try sink.add(cursor, cursor + 1, .punctuation);
            cursor += 1;
        },
        ':' => {
            try sink.add(cursor, cursor + 1, .operator);
            cursor += 1;
        },
        '|', '>' => {
            const marker_start = cursor;
            cursor += 1;
            while (cursor < line_end and (source[cursor] == '+' or source[cursor] == '-' or std.ascii.isDigit(source[cursor]))) cursor += 1;
            try sink.add(marker_start, cursor, .operator);
            block_scalar = true;
        },
        '+', '-', '0'...'9' => cursor = try scanNumberLike(source, cursor, line_end, sink),
        else => if (isPlainStart(source[cursor])) {
            const token_start = cursor;
            cursor += 1;
            while (cursor < line_end and isPlainContinue(source[cursor])) cursor += 1;
            const word = source[token_start..cursor];
            if (nextIsColon(source, cursor, line_end)) {
                try sink.add(token_start, cursor, .property);
            } else if (isBoolean(word)) {
                try sink.add(token_start, cursor, .boolean);
            } else if (isNull(word)) {
                try sink.add(token_start, cursor, .constant);
            }
        } else {
            cursor += 1;
        },
    };
    return block_scalar;
}

fn scanQuoted(source: []const u8, start: usize, line_end: usize, sink: *CaptureSink) HighlightError!usize {
    const quote = source[start];
    var cursor = start + 1;
    while (cursor < line_end) {
        if (quote == '"' and source[cursor] == '\\') {
            const end = yamlEscapeEnd(source, cursor, line_end);
            try sink.add(cursor, end, .escape);
            cursor = end;
            continue;
        }
        if (source[cursor] == quote) {
            if (quote == '\'' and cursor + 1 < line_end and source[cursor + 1] == quote) {
                try sink.add(cursor, cursor + 2, .escape);
                cursor += 2;
                continue;
            }
            cursor += 1;
            break;
        }
        cursor += 1;
    }
    try sink.add(start, cursor, if (nextIsColon(source, cursor, line_end)) .property else .string);
    return cursor;
}

fn scanNumberLike(source: []const u8, start: usize, line_end: usize, sink: *CaptureSink) HighlightError!usize {
    var cursor = start + 1;
    while (cursor < line_end) {
        const byte = source[cursor];
        if (std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.' or byte == ':' or byte == '+' or byte == '-') {
            cursor += 1;
        } else break;
    }
    try sink.add(start, cursor, .number);
    return cursor;
}

fn yamlEscapeEnd(source: []const u8, start: usize, line_end: usize) usize {
    if (start + 1 >= line_end or source[start + 1] >= 0x80) {
        return utf8.escapedSequenceEnd(source, start, line_end);
    }
    var end = start + 2;
    const digits: usize = switch (source[start + 1]) {
        'x' => 2,
        'u' => 4,
        'U' => 8,
        else => 0,
    };
    var count: usize = 0;
    while (end < line_end and count < digits and std.ascii.isHex(source[end])) : (count += 1) end += 1;
    return end;
}

fn nextIsColon(source: []const u8, start: usize, line_end: usize) bool {
    var cursor = start;
    while (cursor < line_end and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    return cursor < line_end and source[cursor] == ':';
}
fn isDocumentMarker(line: []const u8) bool {
    const trimmed = std.mem.trimEnd(u8, line, " \t\r");
    return std.mem.eql(u8, trimmed, "---") or std.mem.eql(u8, trimmed, "...");
}
fn isNameByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}
fn isPlainStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}
fn isPlainContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}
fn isBoolean(word: []const u8) bool {
    return std.ascii.eqlIgnoreCase(word, "true") or std.ascii.eqlIgnoreCase(word, "false");
}
fn isNull(word: []const u8) bool {
    return std.ascii.eqlIgnoreCase(word, "null") or std.mem.eql(u8, word, "~");
}
