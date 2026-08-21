const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "json",
    .display_name = "JSON",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *CaptureSink,
    index: usize = 0,

    fn run(scanner: *Scanner) HighlightError!void {
        while (scanner.index < scanner.source.len) {
            switch (scanner.source[scanner.index]) {
                '{', '}', '[', ']', ',', ':' => {
                    try scanner.sink.add(scanner.index, scanner.index + 1, .punctuation);
                    scanner.index += 1;
                },
                '"' => try scanner.scanString(),
                '-' => try scanner.scanNumber(),
                '0'...'9' => try scanner.scanNumber(),
                't' => if (try scanner.scanLiteral("true", .boolean)) {} else {
                    scanner.index += 1;
                },
                'f' => if (try scanner.scanLiteral("false", .boolean)) {} else {
                    scanner.index += 1;
                },
                'n' => if (try scanner.scanLiteral("null", .constant)) {} else {
                    scanner.index += 1;
                },
                else => scanner.index += 1,
            }
        }
    }

    fn scanString(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        var cursor = start + 1;
        var terminated = false;

        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == '"') {
                cursor += 1;
                terminated = true;
                break;
            }
            if (scanner.source[cursor] == '\\') {
                const escape_end = jsonEscapeEnd(scanner.source, cursor);
                try scanner.sink.add(cursor, escape_end, .escape);
                cursor = escape_end;
                continue;
            }
            cursor += 1;
        }

        const scope: Scope = if (terminated and
            nextNonWhitespaceIsColon(scanner.source, cursor))
            .property
        else
            .string;
        try scanner.sink.add(start, cursor, scope);
        scanner.index = cursor;
    }

    fn scanNumber(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        var cursor = start;

        if (scanner.source[cursor] == '-') cursor += 1;
        if (cursor < scanner.source.len and scanner.source[cursor] == '0') {
            cursor += 1;
        } else {
            while (cursor < scanner.source.len and std.ascii.isDigit(scanner.source[cursor])) {
                cursor += 1;
            }
        }

        if (cursor < scanner.source.len and scanner.source[cursor] == '.') {
            cursor += 1;
            while (cursor < scanner.source.len and std.ascii.isDigit(scanner.source[cursor])) {
                cursor += 1;
            }
        }

        if (cursor < scanner.source.len and
            (scanner.source[cursor] == 'e' or scanner.source[cursor] == 'E'))
        {
            cursor += 1;
            if (cursor < scanner.source.len and
                (scanner.source[cursor] == '+' or scanner.source[cursor] == '-'))
            {
                cursor += 1;
            }
            while (cursor < scanner.source.len and std.ascii.isDigit(scanner.source[cursor])) {
                cursor += 1;
            }
        }

        try scanner.sink.add(start, cursor, .number);
        scanner.index = cursor;
    }

    fn scanLiteral(
        scanner: *Scanner,
        literal: []const u8,
        scope: Scope,
    ) HighlightError!bool {
        const remaining = scanner.source[scanner.index..];
        var matched: usize = 0;
        while (matched < remaining.len and
            matched < literal.len and
            remaining[matched] == literal[matched])
        {
            matched += 1;
        }
        if (matched == 0 or !isLiteralBoundary(remaining[matched..])) return false;

        const capture_length = if (matched == literal.len) literal.len else matched;
        try scanner.sink.add(scanner.index, scanner.index + capture_length, scope);
        scanner.index += capture_length;
        return true;
    }
};

fn jsonEscapeEnd(source: []const u8, start: usize) usize {
    var end = @min(start + 2, source.len);
    if (end < source.len and source[start + 1] == 'u') {
        var digits: u3 = 0;
        while (end < source.len and digits < 4 and std.ascii.isHex(source[end])) {
            end += 1;
            digits += 1;
        }
    }
    return end;
}

fn nextNonWhitespaceIsColon(source: []const u8, start: usize) bool {
    var cursor = start;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return cursor < source.len and source[cursor] == ':';
}

fn isLiteralBoundary(remaining: []const u8) bool {
    return remaining.len == 0 or switch (remaining[0]) {
        ' ', '\t', '\r', '\n', ',', ']', '}' => true,
        else => false,
    };
}
