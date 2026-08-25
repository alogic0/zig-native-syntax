const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "python",
    .display_name = "Python",
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
    next_identifier_scope: ?@import("../scope.zig").Scope = null,

    fn run(scanner: *Scanner) HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.source[scanner.index] == '#') {
                try scanner.scanComment();
            } else if (scanner.source[scanner.index] == '@') {
                try scanner.scanDecorator();
            } else if (stringPrefix(scanner.source, scanner.index)) |prefix| {
                try scanner.scanString(prefix);
            } else switch (scanner.source[scanner.index]) {
                '0'...'9' => try scanner.scanNumber(),
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', ':' => try scanner.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', '.', ';' => try scanner.captureByte(.punctuation),
                else => if (isIdentifierStart(scanner.source[scanner.index])) {
                    try scanner.scanIdentifier();
                } else {
                    scanner.index += 1;
                },
            }
        }
    }

    fn captureByte(scanner: *Scanner, scope: @import("../scope.zig").Scope) HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }

    fn scanComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanDecorator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and
            (isIdentifierContinue(scanner.source[scanner.index]) or scanner.source[scanner.index] == '.'))
        {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .attribute);
    }

    fn scanString(scanner: *Scanner, prefix: StringPrefix) HighlightError!void {
        const start = scanner.index;
        const quote_index = start + prefix.length;
        const quote = scanner.source[quote_index];
        const triple = quote_index + 2 < scanner.source.len and
            scanner.source[quote_index + 1] == quote and
            scanner.source[quote_index + 2] == quote;
        var cursor = quote_index + if (triple) @as(usize, 3) else 1;
        while (cursor < scanner.source.len) {
            if (!prefix.raw and scanner.source[cursor] == '\\') {
                const end = escapeEnd(scanner.source, cursor);
                try scanner.sink.add(cursor, end, .escape);
                cursor = end;
                continue;
            }
            if (triple) {
                if (cursor + 2 < scanner.source.len and
                    scanner.source[cursor] == quote and
                    scanner.source[cursor + 1] == quote and
                    scanner.source[cursor + 2] == quote)
                {
                    cursor += 3;
                    break;
                }
            } else {
                cursor += 1;
                if (scanner.source[cursor - 1] == quote) break;
                if (scanner.source[cursor - 1] == '\n') break;
                continue;
            }
            cursor += 1;
        }
        try scanner.sink.add(start, cursor, .string);
        scanner.index = cursor;
    }

    fn scanNumber(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            const byte = scanner.source[scanner.index];
            if (std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.') {
                scanner.index += 1;
            } else if ((byte == '+' or byte == '-') and scanner.index > start and
                (scanner.source[scanner.index - 1] == 'e' or scanner.source[scanner.index - 1] == 'E'))
            {
                scanner.index += 1;
            } else break;
        }
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanOperator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isOperatorByte(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn scanIdentifier(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        const word = scanner.source[start..scanner.index];
        if (scanner.next_identifier_scope) |scope| {
            try scanner.sink.add(start, scanner.index, scope);
            scanner.next_identifier_scope = null;
        } else if (isKeyword(word)) {
            try scanner.sink.add(start, scanner.index, .keyword);
            if (std.mem.eql(u8, word, "def")) scanner.next_identifier_scope = .function;
            if (std.mem.eql(u8, word, "class")) scanner.next_identifier_scope = .type;
        } else if (std.mem.eql(u8, word, "True") or std.mem.eql(u8, word, "False")) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (std.mem.eql(u8, word, "None") or std.mem.eql(u8, word, "Ellipsis") or
            std.mem.eql(u8, word, "NotImplemented"))
        {
            try scanner.sink.add(start, scanner.index, .constant);
        } else if (isBuiltinType(word)) {
            try scanner.sink.add(start, scanner.index, .builtin);
            try scanner.sink.add(start, scanner.index, .type);
        } else if (isBuiltin(word)) {
            try scanner.sink.add(start, scanner.index, .builtin);
        } else {
            try scanner.sink.add(start, scanner.index, .variable);
        }
    }
};

fn escapeEnd(source: []const u8, start: usize) usize {
    const escaped_start = start + 1;
    if (escaped_start >= source.len) return source.len;
    const len = validUtf8SequenceLength(source[escaped_start..]) orelse 1;
    return escaped_start + len;
}

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

const StringPrefix = struct { length: usize, raw: bool };

fn stringPrefix(source: []const u8, start: usize) ?StringPrefix {
    if (start >= source.len) return null;
    if (source[start] == '"' or source[start] == '\'') return .{ .length = 0, .raw = false };
    if (!std.ascii.isAlphabetic(source[start])) return null;
    var cursor = start;
    var raw = false;
    while (cursor < source.len and cursor - start < 3) : (cursor += 1) {
        switch (std.ascii.toLower(source[cursor])) {
            'r' => raw = true,
            'b', 'u', 'f' => {},
            else => break,
        }
    }
    if (cursor > start and cursor < source.len and (source[cursor] == '"' or source[cursor] == '\'')) {
        return .{ .length = cursor - start, .raw = raw };
    }
    return null;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}
fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
fn isOperatorByte(byte: u8) bool {
    return std.mem.indexOfScalar(u8, "+-*/%=!<>&|^~:", byte) != null;
}

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{
        "and",  "as",     "assert", "async", "await",  "break",   "case",     "class", "continue",
        "def",  "del",    "elif",   "else",  "except", "finally", "for",      "from",  "global",
        "if",   "import", "in",     "is",    "lambda", "match",   "nonlocal", "not",   "or",
        "pass", "raise",  "return", "try",   "while",  "with",    "yield",
    };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

fn isBuiltinType(word: []const u8) bool {
    const words = [_][]const u8{ "bool", "bytes", "bytearray", "complex", "dict", "float", "frozenset", "int", "list", "memoryview", "object", "range", "set", "slice", "str", "tuple", "type" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

fn isBuiltin(word: []const u8) bool {
    const words = [_][]const u8{ "abs", "all", "any", "enumerate", "filter", "getattr", "hasattr", "isinstance", "iter", "len", "map", "max", "min", "next", "open", "print", "repr", "reversed", "round", "sorted", "sum", "super", "zip", "__name__" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
