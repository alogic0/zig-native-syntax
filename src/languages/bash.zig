const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "bash",
    .display_name = "Bash",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    defer scanner.pending_heredocs.deinit(sink.allocator);
    try scanner.run();
}

const Heredoc = struct {
    delimiter: []const u8,
    strip_tabs: bool,
};

const Scanner = struct {
    source: []const u8,
    sink: *CaptureSink,
    index: usize = 0,
    line_start: usize = 0,
    pending_heredocs: std.ArrayList(Heredoc) = .empty,

    fn run(scanner: *Scanner) HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.index == scanner.line_start and scanner.pending_heredocs.items.len > 0) {
                try scanner.scanHeredocLine();
                continue;
            }

            const byte = scanner.source[scanner.index];
            switch (byte) {
                '\n' => {
                    scanner.index += 1;
                    scanner.line_start = scanner.index;
                },
                '\'', '"' => try scanner.scanQuoted(byte, scanner.index),
                '`' => try scanner.scanBackticks(scanner.index),
                '$' => scanner.index = try scanner.scanDollar(scanner.index),
                '\\' => {
                    const end = @min(scanner.index + 2, scanner.source.len);
                    try scanner.sink.add(scanner.index, end, .escape);
                    scanner.index = end;
                },
                '#' => if (scanner.startsComment()) {
                    const end = std.mem.indexOfScalarPos(u8, scanner.source, scanner.index, '\n') orelse scanner.source.len;
                    try scanner.sink.add(scanner.index, end, .comment);
                    scanner.index = end;
                } else {
                    scanner.index += 1;
                },
                '<' => if (scanner.index + 1 < scanner.source.len and
                    scanner.source[scanner.index + 1] == '<')
                {
                    try scanner.scanHeredocStart();
                } else {
                    try scanner.scanOperator();
                },
                '|', '&', ';', '>', '(', ')' => try scanner.scanOperator(),
                '[', ']', '{', '}' => {
                    try scanner.sink.add(scanner.index, scanner.index + 1, .punctuation);
                    scanner.index += 1;
                },
                else => if (std.ascii.isDigit(byte)) {
                    const start = scanner.index;
                    while (scanner.index < scanner.source.len and
                        (std.ascii.isDigit(scanner.source[scanner.index]) or
                            scanner.source[scanner.index] == '_'))
                    {
                        scanner.index += 1;
                    }
                    try scanner.sink.add(start, scanner.index, .number);
                } else if (isIdentifierStart(byte)) {
                    const start = scanner.index;
                    scanner.index += 1;
                    while (scanner.index < scanner.source.len and
                        isIdentifierContinue(scanner.source[scanner.index]))
                    {
                        scanner.index += 1;
                    }
                    if (isKeyword(scanner.source[start..scanner.index])) {
                        try scanner.sink.add(start, scanner.index, .keyword);
                    }
                } else {
                    scanner.index += 1;
                },
            }
        }
    }

    fn scanQuoted(scanner: *Scanner, quote: u8, start: usize) HighlightError!void {
        var cursor = start + 1;
        while (cursor < scanner.source.len) {
            if (quote == '"' and scanner.source[cursor] == '\\') {
                const end = @min(cursor + 2, scanner.source.len);
                try scanner.sink.add(cursor, end, .escape);
                cursor = end;
                continue;
            }
            if (quote == '"' and scanner.source[cursor] == '$') {
                cursor = try scanner.scanDollar(cursor);
                continue;
            }
            if (quote == '"' and scanner.source[cursor] == '`') {
                cursor = try scanner.captureBackticks(cursor);
                continue;
            }
            cursor += 1;
            if (scanner.source[cursor - 1] == quote) break;
        }
        try scanner.sink.add(start, cursor, .string);
        scanner.index = cursor;
    }

    fn scanBackticks(scanner: *Scanner, start: usize) HighlightError!void {
        scanner.index = try scanner.captureBackticks(start);
    }

    fn captureBackticks(scanner: *Scanner, start: usize) HighlightError!usize {
        var cursor = start + 1;
        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == '\\') {
                cursor = @min(cursor + 2, scanner.source.len);
                continue;
            }
            cursor += 1;
            if (scanner.source[cursor - 1] == '`') break;
        }
        try scanner.sink.add(start, cursor, .embedded);
        return cursor;
    }

    fn scanDollar(scanner: *Scanner, start: usize) HighlightError!usize {
        if (start + 1 >= scanner.source.len) return start + 1;
        const next = scanner.source[start + 1];

        if (next == '\'' or next == '"') {
            var cursor = start + 2;
            while (cursor < scanner.source.len) {
                if (scanner.source[cursor] == '\\') {
                    const end = @min(cursor + 2, scanner.source.len);
                    try scanner.sink.add(cursor, end, .escape);
                    cursor = end;
                    continue;
                }
                cursor += 1;
                if (scanner.source[cursor - 1] == next) break;
            }
            try scanner.sink.add(start, cursor, .string);
            return cursor;
        }

        if (next == '{') {
            const end = findBalanced(scanner.source, start + 1, '{', '}');
            try scanner.sink.add(start, end, .variable);
            return end;
        }
        if (next == '(') {
            const arithmetic = start + 2 < scanner.source.len and scanner.source[start + 2] == '(';
            const end = if (arithmetic)
                findArithmeticEnd(scanner.source, start + 3)
            else
                findBalanced(scanner.source, start + 1, '(', ')');
            try scanner.sink.add(start, end, .embedded);
            return end;
        }
        if (isIdentifierStart(next)) {
            var end = start + 2;
            while (end < scanner.source.len and isIdentifierContinue(scanner.source[end])) end += 1;
            try scanner.sink.add(start, end, .variable);
            return end;
        }
        if (std.ascii.isDigit(next) or std.mem.indexOfScalar(u8, "?*$#@!-_", next) != null) {
            try scanner.sink.add(start, start + 2, .variable);
            return start + 2;
        }
        return start + 1;
    }

    fn scanOperator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        const first = scanner.source[start];
        scanner.index += 1;
        if (scanner.index < scanner.source.len) {
            const second = scanner.source[scanner.index];
            if ((first == '|' and second == '|') or
                (first == '&' and second == '&') or
                (first == ';' and second == ';') or
                (first == '>' and second == '>') or
                (first == '<' and second == '<'))
            {
                scanner.index += 1;
            }
        }
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn scanHeredocStart(scanner: *Scanner) HighlightError!void {
        const operator_start = scanner.index;
        scanner.index += 2;
        if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '<') {
            scanner.index += 1;
            try scanner.sink.add(operator_start, scanner.index, .operator);
            return;
        }

        var strip_tabs = false;
        if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '-') {
            strip_tabs = true;
            scanner.index += 1;
        }
        try scanner.sink.add(operator_start, scanner.index, .operator);
        while (scanner.index < scanner.source.len and
            (scanner.source[scanner.index] == ' ' or scanner.source[scanner.index] == '\t'))
        {
            scanner.index += 1;
        }
        if (scanner.index >= scanner.source.len or scanner.source[scanner.index] == '\n') return;

        const label_start = scanner.index;
        var delimiter_start = label_start;
        var delimiter_end: usize = undefined;
        if (scanner.source[scanner.index] == '\'' or scanner.source[scanner.index] == '"') {
            const quote = scanner.source[scanner.index];
            delimiter_start += 1;
            scanner.index += 1;
            while (scanner.index < scanner.source.len and
                scanner.source[scanner.index] != quote and
                scanner.source[scanner.index] != '\n')
            {
                scanner.index += 1;
            }
            delimiter_end = scanner.index;
            if (scanner.index < scanner.source.len and scanner.source[scanner.index] == quote) {
                scanner.index += 1;
            }
        } else {
            while (scanner.index < scanner.source.len and
                !std.ascii.isWhitespace(scanner.source[scanner.index]) and
                std.mem.indexOfScalar(u8, ";|&<>()", scanner.source[scanner.index]) == null)
            {
                scanner.index += 1;
            }
            delimiter_end = scanner.index;
        }
        if (delimiter_end == delimiter_start) return;
        try scanner.sink.add(label_start, scanner.index, .label);
        try scanner.pending_heredocs.append(scanner.sink.allocator, .{
            .delimiter = scanner.source[delimiter_start..delimiter_end],
            .strip_tabs = strip_tabs,
        });
    }

    fn scanHeredocLine(scanner: *Scanner) HighlightError!void {
        const heredoc = scanner.pending_heredocs.items[0];
        const content_end = std.mem.indexOfScalarPos(u8, scanner.source, scanner.index, '\n') orelse scanner.source.len;
        var comparison_start = scanner.index;
        if (heredoc.strip_tabs) {
            while (comparison_start < content_end and scanner.source[comparison_start] == '\t') {
                comparison_start += 1;
            }
        }
        const comparison_end = if (content_end > comparison_start and
            scanner.source[content_end - 1] == '\r') content_end - 1 else content_end;
        const line_end = if (content_end < scanner.source.len) content_end + 1 else content_end;

        if (std.mem.eql(u8, scanner.source[comparison_start..comparison_end], heredoc.delimiter)) {
            try scanner.sink.add(comparison_start, comparison_end, .label);
            _ = scanner.pending_heredocs.orderedRemove(0);
        } else {
            try scanner.sink.add(scanner.index, line_end, .string);
        }
        scanner.index = line_end;
        scanner.line_start = line_end;
    }

    fn startsComment(scanner: Scanner) bool {
        if (scanner.index == scanner.line_start) return true;
        const previous = scanner.source[scanner.index - 1];
        return std.ascii.isWhitespace(previous) or
            std.mem.indexOfScalar(u8, ";|&(){}", previous) != null;
    }
};

fn findBalanced(source: []const u8, open_index: usize, open: u8, close: u8) usize {
    var depth: usize = 1;
    var cursor = open_index + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '\\') {
            cursor = @min(cursor + 1, source.len);
            continue;
        }
        if (source[cursor] == open) depth += 1;
        if (source[cursor] == close) {
            depth -= 1;
            if (depth == 0) return cursor + 1;
        }
    }
    return source.len;
}

fn findArithmeticEnd(source: []const u8, start: usize) usize {
    var depth: usize = 1;
    var cursor = start;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '(') depth += 1;
        if (source[cursor] == ')') {
            if (depth == 1 and cursor + 1 < source.len and source[cursor + 1] == ')') {
                return cursor + 2;
            }
            depth -= 1;
        }
    }
    return source.len;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "if",     "then", "else",   "elif", "fi",   "for", "while",
        "until",  "do",   "done",   "case", "esac", "in",  "function",
        "select", "time", "coproc",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) return true;
    }
    return false;
}
