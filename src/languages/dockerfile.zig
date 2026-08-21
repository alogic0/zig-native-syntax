const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "dockerfile",
    .display_name = "Dockerfile",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, line_start, '\n') orelse source.len;
        try scanLine(source, line_start, line_end, sink);
        line_start = if (line_end < source.len) line_end + 1 else source.len;
    }
}

fn scanLine(source: []const u8, line_start: usize, line_end: usize, sink: *CaptureSink) HighlightError!void {
    var cursor = line_start;
    while (cursor < line_end and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    if (cursor >= line_end) return;
    if (source[cursor] == '#') {
        const scope: @import("../scope.zig").Scope = if (startsDirective(source[cursor..line_end])) .special else .comment;
        try sink.add(cursor, line_end, scope);
        return;
    }

    const instruction_start = cursor;
    while (cursor < line_end and std.ascii.isAlphabetic(source[cursor])) cursor += 1;
    if (cursor > instruction_start and isInstruction(source[instruction_start..cursor])) {
        try sink.add(instruction_start, cursor, .keyword);
    } else {
        cursor = instruction_start;
    }

    while (cursor < line_end) switch (source[cursor]) {
        '"', '\'' => cursor = try scanString(source, cursor, line_end, sink),
        '$' => cursor = try scanVariable(source, cursor, line_end, sink),
        '-' => if (cursor + 1 < line_end and source[cursor + 1] == '-') {
            const start = cursor;
            cursor += 2;
            while (cursor < line_end and
                (std.ascii.isAlphanumeric(source[cursor]) or source[cursor] == '-' or source[cursor] == '_'))
            {
                cursor += 1;
            }
            try sink.add(start, cursor, .attribute);
        } else {
            try sink.add(cursor, cursor + 1, .operator);
            cursor += 1;
        },
        '\\' => {
            const end = @min(cursor + 2, line_end);
            try sink.add(cursor, end, .escape);
            cursor = end;
        },
        '[', ']', '{', '}', '(', ')', ',' => {
            try sink.add(cursor, cursor + 1, .punctuation);
            cursor += 1;
        },
        '=', ';' => {
            try sink.add(cursor, cursor + 1, .operator);
            cursor += 1;
        },
        '&', '|', '<', '>' => {
            const start = cursor;
            const byte = source[cursor];
            cursor += 1;
            if (cursor < line_end and source[cursor] == byte) cursor += 1;
            try sink.add(start, cursor, .operator);
        },
        '0'...'9' => {
            const start = cursor;
            cursor += 1;
            while (cursor < line_end and
                (std.ascii.isDigit(source[cursor]) or source[cursor] == '.' or source[cursor] == ':'))
            {
                cursor += 1;
            }
            try sink.add(start, cursor, .number);
        },
        else => if (isWordStart(source[cursor])) {
            const start = cursor;
            cursor += 1;
            while (cursor < line_end and isWordContinue(source[cursor])) cursor += 1;
            const word = source[start..cursor];
            if (std.ascii.eqlIgnoreCase(word, "as")) try sink.add(start, cursor, .keyword);
        } else {
            cursor += 1;
        },
    };
}

fn scanString(source: []const u8, start: usize, line_end: usize, sink: *CaptureSink) HighlightError!usize {
    const quote = source[start];
    var cursor = start + 1;
    while (cursor < line_end) {
        if (quote == '"' and source[cursor] == '\\') {
            const end = @min(cursor + 2, line_end);
            try sink.add(cursor, end, .escape);
            cursor = end;
            continue;
        }
        if (quote == '"' and source[cursor] == '$') {
            cursor = try scanVariable(source, cursor, line_end, sink);
            continue;
        }
        cursor += 1;
        if (source[cursor - 1] == quote) break;
    }
    try sink.add(start, cursor, .string);
    return cursor;
}

fn scanVariable(source: []const u8, start: usize, line_end: usize, sink: *CaptureSink) HighlightError!usize {
    var cursor = start + 1;
    if (cursor < line_end and source[cursor] == '{') {
        cursor += 1;
        while (cursor < line_end and source[cursor] != '}') cursor += 1;
        if (cursor < line_end) cursor += 1;
    } else {
        while (cursor < line_end and isWordContinue(source[cursor])) cursor += 1;
    }
    if (cursor > start + 1) try sink.add(start, cursor, .variable);
    return cursor;
}

fn startsDirective(line: []const u8) bool {
    return std.ascii.startsWithIgnoreCase(line, "# syntax=") or
        std.ascii.startsWithIgnoreCase(line, "# escape=") or
        std.ascii.startsWithIgnoreCase(line, "# check=");
}

fn isInstruction(word: []const u8) bool {
    const instructions = [_][]const u8{
        "add",        "arg",     "cmd",     "copy",        "entrypoint",
        "env",        "expose",  "from",    "healthcheck", "label",
        "maintainer", "onbuild", "run",     "shell",       "stopsignal",
        "user",       "volume",  "workdir",
    };
    for (instructions) |instruction| {
        if (std.ascii.eqlIgnoreCase(word, instruction)) return true;
    }
    return false;
}

fn isWordStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isWordContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
