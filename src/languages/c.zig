const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "c",
    .display_name = "C",
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
    line_start: usize = 0,

    fn run(scanner: *Scanner) HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.atPreprocessorStart()) {
                try scanner.scanPreprocessor();
            } else if (scanner.startsWith("//")) {
                try scanner.scanLineComment();
            } else if (scanner.startsWith("/*")) {
                try scanner.scanBlockComment();
            } else if (literalPrefix(scanner.source, scanner.index)) |prefix| {
                try scanner.scanLiteral(prefix);
            } else switch (scanner.source[scanner.index]) {
                '\n' => {
                    scanner.index += 1;
                    scanner.line_start = scanner.index;
                },
                '0'...'9' => try scanner.scanNumber(),
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', '?' => try scanner.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', '.', ';', ':' => try scanner.captureByte(.punctuation),
                else => if (isIdentifierStart(scanner.source[scanner.index])) {
                    try scanner.scanIdentifier();
                } else {
                    scanner.index += 1;
                },
            }
        }
    }

    fn startsWith(scanner: Scanner, text: []const u8) bool {
        return std.mem.startsWith(u8, scanner.source[scanner.index..], text);
    }

    fn captureByte(scanner: *Scanner, scope: @import("../scope.zig").Scope) HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }

    fn atPreprocessorStart(scanner: Scanner) bool {
        if (scanner.source[scanner.index] != '#') return false;
        for (scanner.source[scanner.line_start..scanner.index]) |byte| {
            if (byte != ' ' and byte != '\t') return false;
        }
        return true;
    }

    fn scanPreprocessor(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        var end = scanner.index;
        while (end < scanner.source.len) {
            const newline = std.mem.indexOfScalarPos(u8, scanner.source, end, '\n') orelse scanner.source.len;
            end = newline;
            var before = end;
            while (before > start and (scanner.source[before - 1] == ' ' or scanner.source[before - 1] == '\t')) before -= 1;
            if (before == start or scanner.source[before - 1] != '\\' or end == scanner.source.len) break;
            end += 1;
        }
        try scanner.sink.add(start, end, .macro);
        scanner.index = end;
    }

    fn scanLineComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
        if (start + 2 < scanner.source.len and (scanner.source[start + 2] == '/' or scanner.source[start + 2] == '!')) {
            try scanner.sink.add(start, scanner.index, .documentation);
        }
    }

    fn scanBlockComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 2;
        while (scanner.index < scanner.source.len and !scanner.startsWith("*/")) scanner.index += 1;
        if (scanner.index < scanner.source.len) scanner.index += 2;
        try scanner.sink.add(start, scanner.index, .comment);
        if (start + 2 < scanner.source.len and (scanner.source[start + 2] == '*' or scanner.source[start + 2] == '!')) {
            try scanner.sink.add(start, scanner.index, .documentation);
        }
    }

    fn scanLiteral(scanner: *Scanner, prefix: LiteralPrefix) HighlightError!void {
        const start = scanner.index;
        const quote = scanner.source[start + prefix.length];
        var cursor = start + prefix.length + 1;
        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == '\\') {
                const end = cEscapeEnd(scanner.source, cursor);
                try scanner.sink.add(cursor, end, .escape);
                cursor = end;
                continue;
            }
            cursor += 1;
            if (scanner.source[cursor - 1] == quote) break;
            if (scanner.source[cursor - 1] == '\n') break;
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
                (scanner.source[scanner.index - 1] == 'e' or scanner.source[scanner.index - 1] == 'E' or
                    scanner.source[scanner.index - 1] == 'p' or scanner.source[scanner.index - 1] == 'P'))
            {
                scanner.index += 1;
            } else break;
        }
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanOperator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and
            std.mem.indexOfScalar(u8, "+-*/%=!<>&|^~?", scanner.source[scanner.index]) != null)
        {
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
        if (isKeyword(word)) {
            try scanner.sink.add(start, scanner.index, .keyword);
        } else if (isType(word)) {
            try scanner.sink.add(start, scanner.index, .builtin);
            try scanner.sink.add(start, scanner.index, .type);
        } else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false")) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (std.mem.eql(u8, word, "NULL") or std.mem.eql(u8, word, "nullptr")) {
            try scanner.sink.add(start, scanner.index, .constant);
        } else {
            var next = scanner.index;
            while (next < scanner.source.len and std.ascii.isWhitespace(scanner.source[next])) next += 1;
            try scanner.sink.add(start, scanner.index, if (next < scanner.source.len and scanner.source[next] == '(') .function else .variable);
        }
    }
};

const LiteralPrefix = struct { length: usize };
fn literalPrefix(source: []const u8, start: usize) ?LiteralPrefix {
    if (source[start] == '"' or source[start] == '\'') return .{ .length = 0 };
    if (start + 1 < source.len and
        (source[start] == 'L' or source[start] == 'u' or source[start] == 'U') and
        (source[start + 1] == '"' or source[start + 1] == '\'')) return .{ .length = 1 };
    if (start + 2 < source.len and source[start] == 'u' and source[start + 1] == '8' and
        (source[start + 2] == '"' or source[start + 2] == '\'')) return .{ .length = 2 };
    return null;
}

fn cEscapeEnd(source: []const u8, start: usize) usize {
    var end = @min(start + 2, source.len);
    if (start + 1 >= source.len) return end;
    const max_digits: usize = switch (source[start + 1]) {
        'x' => 2,
        'u' => 4,
        'U' => 8,
        else => 0,
    };
    var digits: usize = 0;
    while (end < source.len and digits < max_digits and std.ascii.isHex(source[end])) : (digits += 1) end += 1;
    return end;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}
fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{
        "_Alignas",  "_Alignof",      "_Atomic",       "_Generic", "_Noreturn", "_Static_assert", "_Thread_local",
        "alignas",   "alignof",       "asm",           "auto",     "break",     "case",           "const",
        "constexpr", "continue",      "default",       "do",       "else",      "enum",           "extern",
        "for",       "goto",          "if",            "inline",   "register",  "restrict",       "return",
        "sizeof",    "static",        "static_assert", "struct",   "switch",    "thread_local",   "typedef",
        "typeof",    "typeof_unqual", "union",         "volatile", "while",
    };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
fn isType(word: []const u8) bool {
    const words = [_][]const u8{ "_Bool", "bool", "char", "double", "float", "int", "int8_t", "int16_t", "int32_t", "int64_t", "long", "ptrdiff_t", "short", "signed", "size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "unsigned", "void", "wchar_t" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
