const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;

pub const backend: api.Backend = .init(.{ .canonical_name = "batch", .display_name = "Windows Batch", .kind = .lexical, .support_level = .verified_lexical }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    line_start: usize = 0,

    fn run(scanner: *Scanner) api.HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.atIndentedLineStart() and (scanner.startsWithInsensitive("rem ") or scanner.startsWith("::"))) {
                try scanner.scanToLine(.comment);
            } else switch (scanner.source[scanner.index]) {
                '\n' => {
                    scanner.index += 1;
                    scanner.line_start = scanner.index;
                },
                '"' => try scanner.scanString(),
                '%' => try scanner.scanPercentVariable(),
                '!' => try scanner.scanDelayedVariable(),
                '^' => try scanner.scanEscape(),
                ':' => if (scanner.atIndentedLineStart()) try scanner.scanLabel() else try scanner.captureByte(.operator),
                '0'...'9' => try scanner.scanNumber(),
                'a'...'z', 'A'...'Z', '_' => try scanner.scanWord(),
                '&', '|', '>', '<', '=' => try scanner.scanOperator(),
                '(', ')', ',', '@' => try scanner.captureByte(.punctuation),
                else => scanner.index += validUtf8Length(scanner.source[scanner.index..]),
            }
        }
    }

    fn startsWith(scanner: Scanner, text: []const u8) bool {
        return std.mem.startsWith(u8, scanner.source[scanner.index..], text);
    }

    fn startsWithInsensitive(scanner: Scanner, text: []const u8) bool {
        if (scanner.index + text.len > scanner.source.len) return false;
        return std.ascii.eqlIgnoreCase(scanner.source[scanner.index .. scanner.index + text.len], text);
    }

    fn atIndentedLineStart(scanner: Scanner) bool {
        for (scanner.source[scanner.line_start..scanner.index]) |byte| if (byte != ' ' and byte != '\t' and byte != '@') return false;
        return true;
    }

    fn atIndentedOffset(scanner: Scanner, offset: usize) bool {
        for (scanner.source[scanner.line_start..offset]) |byte| if (byte != ' ' and byte != '\t' and byte != '@') return false;
        return true;
    }

    fn scanToLine(scanner: *Scanner, scope: Scope) api.HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, scanner.index, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, scope);
    }

    fn scanString(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            if (scanner.source[scanner.index] == '^') {
                const escape = scanner.index;
                scanner.index += 1;
                if (scanner.index < scanner.source.len) scanner.index += validUtf8Length(scanner.source[scanner.index..]);
                try scanner.sink.add(escape, scanner.index, .escape);
            } else {
                const byte = scanner.source[scanner.index];
                scanner.index += validUtf8Length(scanner.source[scanner.index..]);
                if (byte == '"' or byte == '\n') break;
            }
        }
        try scanner.sink.add(start, scanner.index, .string);
    }

    fn scanPercentVariable(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '%') scanner.index += 1;
        if (scanner.index < scanner.source.len and std.ascii.isDigit(scanner.source[scanner.index])) {
            scanner.index += 1;
        } else {
            while (scanner.index < scanner.source.len and scanner.source[scanner.index] != '%' and scanner.source[scanner.index] != '\n') scanner.index += validUtf8Length(scanner.source[scanner.index..]);
            if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '%') scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .variable);
    }

    fn scanDelayedVariable(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and scanner.source[scanner.index] != '!' and scanner.source[scanner.index] != '\n') scanner.index += validUtf8Length(scanner.source[scanner.index..]);
        if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '!') scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .variable);
    }

    fn scanEscape(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        if (scanner.index < scanner.source.len) scanner.index += validUtf8Length(scanner.source[scanner.index..]);
        try scanner.sink.add(start, scanner.index, .escape);
    }

    fn scanLabel(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and !std.ascii.isWhitespace(scanner.source[scanner.index])) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .label);
    }

    fn scanNumber(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and std.ascii.isDigit(scanner.source[scanner.index])) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanWord(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and (std.ascii.isAlphanumeric(scanner.source[scanner.index]) or scanner.source[scanner.index] == '_' or scanner.source[scanner.index] == '-')) scanner.index += 1;
        const word = scanner.source[start..scanner.index];
        if (isKeyword(word)) try scanner.sink.add(start, scanner.index, .keyword) else if (scanner.atIndentedOffset(start)) try scanner.sink.add(start, scanner.index, .function);
    }

    fn scanOperator(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and std.mem.indexOfScalar(u8, "&|><=", scanner.source[scanner.index]) != null) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn captureByte(scanner: *Scanner, scope: Scope) api.HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }
};

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "call", "cd", "cls", "copy", "del", "do", "echo", "else", "endlocal", "exit", "for", "goto", "if", "in", "move", "not", "pause", "popd", "pushd", "set", "setlocal", "shift", "start" };
    for (words) |candidate| if (std.ascii.eqlIgnoreCase(candidate, word)) return true;
    return false;
}
