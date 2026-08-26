const std = @import("std");
const api = @import("../backend.zig");
const utf8 = @import("../utf8.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "kdl",
    .display_name = "KDL",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var index: usize = 0;
    var node_position = true;
    while (index < source.len) {
        if (std.mem.startsWith(u8, source[index..], "//")) {
            const end = std.mem.indexOfScalarPos(u8, source, index, '\n') orelse source.len;
            try sink.add(index, end, .comment);
            index = end;
        } else if (std.mem.startsWith(u8, source[index..], "/*")) {
            const end = if (std.mem.indexOfPos(u8, source, index + 2, "*/")) |at| at + 2 else source.len;
            try sink.add(index, end, .comment);
            index = end;
        } else if (std.mem.startsWith(u8, source[index..], "/-")) {
            try sink.add(index, index + 2, .special);
            index += 2;
        } else switch (source[index]) {
            '\n', ';' => {
                if (source[index] == ';') try sink.add(index, index + 1, .punctuation);
                index += 1;
                node_position = true;
            },
            '{', '}', '(', ')' => {
                const byte = source[index];
                try sink.add(index, index + 1, .punctuation);
                index += 1;
                node_position = byte == '{' or byte == '}';
            },
            '=' => {
                try sink.add(index, index + 1, .operator);
                index += 1;
            },
            '"' => {
                index = try scanString(source, index, sink);
                node_position = false;
            },
            'r' => if (rawStringEnd(source, index)) |end| {
                try sink.add(index, end, .string);
                index = end;
                node_position = false;
            } else {
                index = try scanWord(source, index, node_position, sink);
                node_position = false;
            },
            '+', '-', '0'...'9' => {
                const start = index;
                index += 1;
                while (index < source.len and (std.ascii.isAlphanumeric(source[index]) or source[index] == '_' or source[index] == '.' or source[index] == '+' or source[index] == '-')) index += 1;
                try sink.add(start, index, .number);
                node_position = false;
            },
            else => if (isWordStart(source[index])) {
                index = try scanWord(source, index, node_position, sink);
                node_position = false;
            } else {
                index += 1;
            },
        }
    }
}

fn scanWord(source: []const u8, start: usize, node_position: bool, sink: *api.CaptureSink) api.HighlightError!usize {
    var end = start + 1;
    while (end < source.len and isWordContinue(source[end])) end += 1;
    const word = source[start..end];
    var next = end;
    while (next < source.len and (source[next] == ' ' or source[next] == '\t')) next += 1;
    const scope: @import("../scope.zig").Scope = if (node_position)
        .tag
    else if (next < source.len and source[next] == '=')
        .property
    else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false"))
        .boolean
    else if (std.mem.eql(u8, word, "null"))
        .constant
    else
        .variable;
    try sink.add(start, end, scope);
    return end;
}

fn scanString(source: []const u8, start: usize, sink: *api.CaptureSink) api.HighlightError!usize {
    var end = start + 1;
    while (end < source.len) {
        if (source[end] == '\\') {
            const escape_end = utf8.escapedSequenceEnd(source, end, source.len);
            try sink.add(end, escape_end, .escape);
            end = escape_end;
        } else {
            end += 1;
            if (source[end - 1] == '"') break;
        }
    }
    try sink.add(start, end, .string);
    return end;
}

fn rawStringEnd(source: []const u8, start: usize) ?usize {
    var quote = start + 1;
    while (quote < source.len and source[quote] == '#') quote += 1;
    if (quote >= source.len or source[quote] != '"') return null;
    const hashes = quote - start - 1;
    var cursor = quote + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '"' and cursor + 1 + hashes <= source.len and allHashes(source[cursor + 1 .. cursor + 1 + hashes])) return cursor + 1 + hashes;
    }
    return source.len;
}

fn allHashes(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != '#') return false;
    return true;
}

fn isWordStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isWordContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}
