const std = @import("std");
const utf8 = @import("../utf8.zig");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "hcl",
    .display_name = "HCL",
    .kind = .lexical,
    .support_level = .verified_lexical,
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
        while (scanner.index < scanner.source.len) switch (scanner.source[scanner.index]) {
            '#' => try scanner.scanLineComment(),
            '/' => if (scanner.hasNext('/')) {
                try scanner.scanLineComment();
            } else if (scanner.hasNext('*')) {
                try scanner.scanBlockComment();
            } else {
                try scanner.scanOperator();
            },
            '"' => try scanner.scanQuotedString(),
            '<' => if (scanner.hasNext('<')) {
                try scanner.scanHeredoc();
            } else {
                try scanner.scanOperator();
            },
            '0'...'9' => try scanner.scanNumber(),
            '{', '}', '[', ']', '(', ')', ',', '.' => try scanner.captureByte(.punctuation),
            '=', '!', '>', '+', '-', '*', '%', '&', '|', '?', ':', '~' => try scanner.scanOperator(),
            else => if (isIdentifierStart(scanner.source[scanner.index])) {
                try scanner.scanWord();
            } else {
                scanner.index += 1;
            },
        };
    }

    fn hasNext(scanner: *const Scanner, byte: u8) bool {
        return scanner.index + 1 < scanner.source.len and scanner.source[scanner.index + 1] == byte;
    }

    fn captureByte(scanner: *Scanner, scope: Scope) HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }

    fn scanLineComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanBlockComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 2;
        while (scanner.index + 1 < scanner.source.len and
            !(scanner.source[scanner.index] == '*' and scanner.source[scanner.index + 1] == '/'))
        {
            scanner.index += 1;
        }
        if (scanner.index + 1 < scanner.source.len) scanner.index += 2 else scanner.index = scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanQuotedString(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and scanner.source[scanner.index] != '\n') {
            if (scanner.source[scanner.index] == '\\') {
                const escape_start = scanner.index;
                scanner.index = hclEscapeEnd(scanner.source, scanner.index);
                try scanner.sink.add(escape_start, scanner.index, .escape);
                continue;
            }
            if (scanner.index + 1 < scanner.source.len and
                (scanner.source[scanner.index] == '$' or scanner.source[scanner.index] == '%') and
                scanner.source[scanner.index + 1] == '{')
            {
                try scanner.sink.add(scanner.index, scanner.index + 2, .embedded);
                scanner.index += 2;
                continue;
            }
            if (scanner.source[scanner.index] == '"') {
                scanner.index += 1;
                break;
            }
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .string);
    }

    fn scanHeredoc(scanner: *Scanner) HighlightError!void {
        const operator_start = scanner.index;
        scanner.index += 2;
        if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '-') scanner.index += 1;
        try scanner.sink.add(operator_start, scanner.index, .operator);
        while (scanner.index < scanner.source.len and
            (scanner.source[scanner.index] == ' ' or scanner.source[scanner.index] == '\t'))
        {
            scanner.index += 1;
        }

        const delimiter_start = scanner.index;
        while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) scanner.index += 1;
        const delimiter = scanner.source[delimiter_start..scanner.index];
        if (delimiter.len == 0) return;
        try scanner.sink.add(delimiter_start, scanner.index, .label);

        const first_newline = std.mem.indexOfScalarPos(u8, scanner.source, scanner.index, '\n') orelse {
            scanner.index = scanner.source.len;
            return;
        };
        const body_start = first_newline + 1;
        var line_start = body_start;
        while (line_start < scanner.source.len) {
            const line_end = std.mem.indexOfScalarPos(u8, scanner.source, line_start, '\n') orelse scanner.source.len;
            var trimmed_start = line_start;
            while (trimmed_start < line_end and
                (scanner.source[trimmed_start] == ' ' or scanner.source[trimmed_start] == '\t'))
            {
                trimmed_start += 1;
            }
            var trimmed_end = line_end;
            if (trimmed_end > trimmed_start and scanner.source[trimmed_end - 1] == '\r') trimmed_end -= 1;
            if (std.mem.eql(u8, scanner.source[trimmed_start..trimmed_end], delimiter)) {
                if (body_start < line_start) try scanner.sink.add(body_start, line_start, .string);
                try scanner.sink.add(trimmed_start, trimmed_end, .label);
                scanner.index = line_end;
                return;
            }
            if (line_end == scanner.source.len) break;
            line_start = line_end + 1;
        }
        if (body_start < scanner.source.len) try scanner.sink.add(body_start, scanner.source.len, .string);
        scanner.index = scanner.source.len;
    }

    fn scanNumber(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            const byte = scanner.source[scanner.index];
            if (std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.') scanner.index += 1 else break;
        }
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanOperator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        if (scanner.index < scanner.source.len and isOperatorPair(scanner.source[start], scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn scanWord(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) scanner.index += 1;
        const word = scanner.source[start..scanner.index];
        const next = nextSignificantByte(scanner.source, scanner.index);
        const scope: Scope = if (isBoolean(word))
            .boolean
        else if (std.mem.eql(u8, word, "null"))
            .constant
        else if (isKeyword(word))
            .keyword
        else if (isBuiltinType(word))
            .type
        else if (next == '(')
            .function
        else if (next == '=')
            .property
        else if (previousSignificantByte(scanner.source, start) == '.')
            .property
        else
            .variable;
        try scanner.sink.add(start, scanner.index, scope);
    }
};

fn hclEscapeEnd(source: []const u8, start: usize) usize {
    if (start + 1 >= source.len or source[start + 1] >= 0x80) {
        return utf8.escapedSequenceEnd(source, start, source.len);
    }
    var end = start + 2;
    const digits: usize = switch (source[start + 1]) {
        'u' => 4,
        'U' => 8,
        else => 0,
    };
    var consumed: usize = 0;
    while (end < source.len and consumed < digits and std.ascii.isHex(source[end])) : (consumed += 1) end += 1;
    return end;
}

fn nextSignificantByte(source: []const u8, start: usize) ?u8 {
    var cursor = start;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

fn previousSignificantByte(source: []const u8, start: usize) ?u8 {
    var cursor = start;
    while (cursor > 0) {
        cursor -= 1;
        if (!std.ascii.isWhitespace(source[cursor])) return source[cursor];
    }
    return null;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}

fn isBoolean(word: []const u8) bool {
    return std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false");
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "check",  "data",     "for",      "if",  "import",    "in",       "locals", "module", "moved",
        "output", "provider", "resource", "run", "terraform", "variable",
    };
    for (keywords) |keyword| if (std.mem.eql(u8, word, keyword)) return true;
    return false;
}

fn isBuiltinType(word: []const u8) bool {
    const types = [_][]const u8{ "any", "bool", "list", "map", "number", "object", "set", "string", "tuple" };
    for (types) |type_name| if (std.mem.eql(u8, word, type_name)) return true;
    return false;
}

fn isOperatorPair(first: u8, second: u8) bool {
    return switch (first) {
        '=' => second == '=' or second == '>',
        '!' => second == '=',
        '<' => second == '=',
        '>' => second == '=',
        '&' => second == '&',
        '|' => second == '|',
        '~' => second == '>',
        else => false,
    };
}
