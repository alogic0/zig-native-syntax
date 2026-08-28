const std = @import("std");
const utf8 = @import("../utf8.zig");
const backend_api = @import("../backend.zig");
const composition = @import("../composition.zig");
const bash = @import("bash.zig");
const json = @import("json.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "dockerfile",
    .display_name = "Dockerfile",
    .kind = .composed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var start: usize = 0;
    while (start < source.len) {
        var end = logicalInstructionEnd(source, start);
        end = extendRunHeredoc(source, start, end);
        try scanInstruction(source, start, end, sink);
        start = if (end < source.len) end + 1 else source.len;
    }
}

fn scanInstruction(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!void {
    var cursor = skipHorizontalSpace(source, start, end);
    if (cursor >= end) return;
    if (source[cursor] == '#') {
        const scope: Scope = if (startsDirective(source[cursor..end])) .special else .comment;
        try sink.add(cursor, end, scope);
        return;
    }

    const instruction_start = cursor;
    while (cursor < end and std.ascii.isAlphabetic(source[cursor])) cursor += 1;
    const instruction = source[instruction_start..cursor];
    if (!isInstruction(instruction)) {
        try scanArguments(source, instruction_start, end, sink);
        return;
    }
    try sink.add(instruction_start, cursor, .keyword);
    cursor = skipSpace(source, cursor, end);
    cursor = try scanLeadingFlags(source, cursor, end, sink);
    cursor = try skipContinuationPrefix(source, cursor, end, sink);

    if (std.ascii.eqlIgnoreCase(instruction, "run")) {
        if (dockerHeredoc(source, cursor, end)) |heredoc| {
            try sink.add(heredoc.operator_start, heredoc.label_start, .operator);
            try sink.add(heredoc.label_start, heredoc.label_end, .label);
            try composition.highlightEmbedded(
                source,
                .{ .start = heredoc.body_start, .end = heredoc.body_end },
                bash.backend,
                sink,
            );
            try sink.add(heredoc.terminator_start, heredoc.terminator_end, .label);
            return;
        }
        try highlightCommand(source, cursor, end, sink);
        return;
    }
    if (std.ascii.eqlIgnoreCase(instruction, "healthcheck")) {
        try highlightHealthcheck(source, cursor, end, sink);
        return;
    }
    if (usesJsonForm(instruction) and cursor < end and source[cursor] == '[') {
        try composition.highlightEmbedded(source, .{ .start = cursor, .end = end }, json.backend, sink);
        return;
    }
    try scanArguments(source, cursor, end, sink);
}

fn skipContinuationPrefix(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!usize {
    var cursor = start;
    while (cursor < end) {
        cursor = skipSpace(source, cursor, end);
        if (cursor + 1 >= end or source[cursor] != '\\' or source[cursor + 1] != '\n') return cursor;
        try sink.add(cursor, cursor + 1, .escape);
        cursor += 2;
    }
    return cursor;
}

fn highlightCommand(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!void {
    if (start >= end) return;
    const nested = if (source[start] == '[') json.backend else bash.backend;
    try composition.highlightEmbedded(source, .{ .start = start, .end = end }, nested, sink);
}

fn highlightHealthcheck(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!void {
    var cursor = start;
    const command_start = cursor;
    while (cursor < end and std.ascii.isAlphabetic(source[cursor])) cursor += 1;
    const command = source[command_start..cursor];
    if (std.ascii.eqlIgnoreCase(command, "none")) {
        try sink.add(command_start, cursor, .keyword);
        return;
    }
    if (!std.ascii.eqlIgnoreCase(command, "cmd")) {
        try scanArguments(source, start, end, sink);
        return;
    }
    try sink.add(command_start, cursor, .keyword);
    cursor = skipSpace(source, cursor, end);
    try highlightCommand(source, cursor, end, sink);
}

fn scanLeadingFlags(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!usize {
    var cursor = start;
    while (cursor + 2 <= end and std.mem.startsWith(u8, source[cursor..end], "--")) {
        const flag_start = cursor;
        cursor += 2;
        while (cursor < end and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
        try sink.add(flag_start, cursor, .attribute);
        cursor = skipSpace(source, cursor, end);
    }
    return cursor;
}

fn scanArguments(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!void {
    var cursor = start;
    while (cursor < end) switch (source[cursor]) {
        '"', '\'' => cursor = try scanString(source, cursor, end, sink),
        '$' => cursor = try scanVariable(source, cursor, end, sink),
        '-' => if (cursor + 1 < end and source[cursor + 1] == '-') {
            const flag_start = cursor;
            cursor += 2;
            while (cursor < end and
                (std.ascii.isAlphanumeric(source[cursor]) or source[cursor] == '-' or source[cursor] == '_'))
            {
                cursor += 1;
            }
            try sink.add(flag_start, cursor, .attribute);
        } else {
            try sink.add(cursor, cursor + 1, .operator);
            cursor += 1;
        },
        '\\' => {
            const escape_end = utf8.escapedSequenceEnd(source, cursor, end);
            try sink.add(cursor, escape_end, .escape);
            cursor = escape_end;
        },
        '[', ']', '{', '}', '(', ')', ',' => {
            try sink.add(cursor, cursor + 1, .punctuation);
            cursor += 1;
        },
        '=', ';', '&', '|', '<', '>' => {
            const operator_start = cursor;
            const byte = source[cursor];
            cursor += 1;
            if (cursor < end and source[cursor] == byte) cursor += 1;
            try sink.add(operator_start, cursor, .operator);
        },
        '0'...'9' => {
            const number_start = cursor;
            cursor += 1;
            while (cursor < end and
                (std.ascii.isDigit(source[cursor]) or source[cursor] == '.' or source[cursor] == ':'))
            {
                cursor += 1;
            }
            try sink.add(number_start, cursor, .number);
        },
        else => if (isWordStart(source[cursor])) {
            const word_start = cursor;
            cursor += 1;
            while (cursor < end and isWordContinue(source[cursor])) cursor += 1;
            if (std.ascii.eqlIgnoreCase(source[word_start..cursor], "as")) {
                try sink.add(word_start, cursor, .keyword);
            }
        } else {
            cursor += 1;
        },
    };
}

fn scanString(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!usize {
    const quote = source[start];
    var cursor = start + 1;
    while (cursor < end) {
        if (quote == '"' and source[cursor] == '\\') {
            const escape_end = utf8.escapedSequenceEnd(source, cursor, end);
            try sink.add(cursor, escape_end, .escape);
            cursor = escape_end;
            continue;
        }
        if (quote == '"' and source[cursor] == '$') {
            cursor = try scanVariable(source, cursor, end, sink);
            continue;
        }
        cursor += 1;
        if (source[cursor - 1] == quote) break;
    }
    try sink.add(start, cursor, .string);
    return cursor;
}

fn scanVariable(source: []const u8, start: usize, end: usize, sink: *CaptureSink) HighlightError!usize {
    var cursor = start + 1;
    if (cursor < end and source[cursor] == '{') {
        cursor += 1;
        while (cursor < end and source[cursor] != '}') cursor += 1;
        if (cursor < end) cursor += 1;
    } else {
        while (cursor < end and isWordContinue(source[cursor])) cursor += 1;
    }
    if (cursor > start + 1) try sink.add(start, cursor, .variable);
    return cursor;
}

fn logicalInstructionEnd(source: []const u8, start: usize) usize {
    var end = lineEnd(source, start);
    while (end < source.len and endsWithContinuation(source, start, end)) {
        end = lineEnd(source, end + 1);
    }
    return end;
}

fn extendRunHeredoc(source: []const u8, start: usize, initial_end: usize) usize {
    var cursor = skipHorizontalSpace(source, start, initial_end);
    const instruction_start = cursor;
    while (cursor < initial_end and std.ascii.isAlphabetic(source[cursor])) cursor += 1;
    if (!std.ascii.eqlIgnoreCase(source[instruction_start..cursor], "run")) return initial_end;
    cursor = skipSpace(source, cursor, initial_end);
    while (cursor + 2 <= initial_end and std.mem.startsWith(u8, source[cursor..initial_end], "--")) {
        while (cursor < initial_end and !std.ascii.isWhitespace(source[cursor])) cursor += 1;
        cursor = skipSpace(source, cursor, initial_end);
    }
    if (cursor < initial_end and source[cursor] == '[') return initial_end;

    const marker = std.mem.indexOfPos(u8, source, cursor, "<<") orelse return initial_end;
    var delimiter_start = marker + 2;
    if (delimiter_start < initial_end and source[delimiter_start] == '-') delimiter_start += 1;
    delimiter_start = skipHorizontalSpace(source, delimiter_start, initial_end);
    if (delimiter_start >= initial_end) return initial_end;
    const quote: ?u8 = if (source[delimiter_start] == '"' or source[delimiter_start] == '\'') source[delimiter_start] else null;
    if (quote != null) delimiter_start += 1;
    var delimiter_end = delimiter_start;
    while (delimiter_end < initial_end and if (quote) |q|
        source[delimiter_end] != q
    else
        !std.ascii.isWhitespace(source[delimiter_end]))
    {
        delimiter_end += 1;
    }
    if (delimiter_end == delimiter_start) return initial_end;
    const delimiter = source[delimiter_start..delimiter_end];

    var body_start = if (initial_end < source.len) initial_end + 1 else source.len;
    while (body_start < source.len) {
        const body_end = lineEnd(source, body_start);
        const line = std.mem.trim(u8, source[body_start..body_end], "\t\r");
        if (std.mem.eql(u8, line, delimiter)) return body_end;
        body_start = if (body_end < source.len) body_end + 1 else source.len;
    }
    return source.len;
}

const DockerHeredoc = struct {
    operator_start: usize,
    label_start: usize,
    label_end: usize,
    body_start: usize,
    body_end: usize,
    terminator_start: usize,
    terminator_end: usize,
};

fn dockerHeredoc(source: []const u8, start: usize, end: usize) ?DockerHeredoc {
    if (start + 2 > end or !std.mem.startsWith(u8, source[start..end], "<<")) return null;
    const first_line_end = lineEnd(source, start);
    if (first_line_end >= end) return null;

    var label_start = start + 2;
    if (label_start < first_line_end and source[label_start] == '-') label_start += 1;
    label_start = skipHorizontalSpace(source, label_start, first_line_end);
    if (label_start >= first_line_end) return null;
    const quote: ?u8 = if (source[label_start] == '"' or source[label_start] == '\'') source[label_start] else null;
    if (quote != null) label_start += 1;
    var label_end = label_start;
    while (label_end < first_line_end and if (quote) |q|
        source[label_end] != q
    else
        !std.ascii.isWhitespace(source[label_end]))
    {
        label_end += 1;
    }
    if (label_end == label_start) return null;
    const delimiter = source[label_start..label_end];

    var line_start = first_line_end + 1;
    while (line_start <= end) {
        const current_end = lineEnd(source, line_start);
        const line = std.mem.trim(u8, source[line_start..current_end], "\t\r");
        if (std.mem.eql(u8, line, delimiter)) {
            return .{
                .operator_start = start,
                .label_start = label_start,
                .label_end = label_end,
                .body_start = first_line_end + 1,
                .body_end = line_start,
                .terminator_start = line_start,
                .terminator_end = current_end,
            };
        }
        if (current_end >= end) break;
        line_start = current_end + 1;
    }
    return null;
}

fn lineEnd(source: []const u8, start: usize) usize {
    return std.mem.indexOfScalarPos(u8, source, start, '\n') orelse source.len;
}

fn endsWithContinuation(source: []const u8, start: usize, end: usize) bool {
    var cursor = end;
    while (cursor > start and (source[cursor - 1] == ' ' or source[cursor - 1] == '\t' or source[cursor - 1] == '\r')) {
        cursor -= 1;
    }
    return cursor > start and source[cursor - 1] == '\\';
}

fn skipHorizontalSpace(source: []const u8, start: usize, end: usize) usize {
    var cursor = start;
    while (cursor < end and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    return cursor;
}

fn skipSpace(source: []const u8, start: usize, end: usize) usize {
    var cursor = start;
    while (cursor < end and std.ascii.isWhitespace(source[cursor])) cursor += 1;
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

fn usesJsonForm(instruction: []const u8) bool {
    const instructions = [_][]const u8{ "add", "cmd", "copy", "entrypoint", "shell", "volume" };
    for (instructions) |candidate| {
        if (std.ascii.eqlIgnoreCase(instruction, candidate)) return true;
    }
    return false;
}

fn isWordStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isWordContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
