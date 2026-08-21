const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "javascript",
    .display_name = "JavaScript",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    try highlightLanguage(source, sink, false);
}

pub fn highlightLanguage(source: []const u8, sink: *CaptureSink, typescript: bool) HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink, .typescript = typescript };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *CaptureSink,
    typescript: bool,
    index: usize = 0,
    next_identifier_scope: ?Scope = null,
    after_dot: bool = false,

    fn run(scanner: *Scanner) HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.startsWith("//")) {
                try scanner.scanLineComment();
            } else if (scanner.startsWith("/*")) {
                try scanner.scanBlockComment();
            } else switch (scanner.source[scanner.index]) {
                '"', '\'' => try scanner.scanString(scanner.source[scanner.index]),
                '`' => try scanner.scanTemplate(),
                '0'...'9' => try scanner.scanNumber(),
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', '?', ':' => try scanner.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', ';' => try scanner.capturePunctuation(false),
                '.' => try scanner.capturePunctuation(true),
                '#' => if (scanner.index + 1 < scanner.source.len and isIdentifierStart(scanner.source[scanner.index + 1])) {
                    const start = scanner.index;
                    scanner.index += 2;
                    while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) scanner.index += 1;
                    try scanner.sink.add(start, scanner.index, .property);
                } else {
                    scanner.index += 1;
                },
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

    fn capturePunctuation(scanner: *Scanner, dot: bool) HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, .punctuation);
        scanner.index += 1;
        scanner.after_dot = dot;
    }

    fn scanLineComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanBlockComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 2;
        while (scanner.index < scanner.source.len and !scanner.startsWith("*/")) scanner.index += 1;
        if (scanner.index < scanner.source.len) scanner.index += 2;
        try scanner.sink.add(start, scanner.index, .comment);
        if (start + 2 < scanner.source.len and scanner.source[start + 2] == '*') {
            try scanner.sink.add(start, scanner.index, .documentation);
        }
    }

    fn scanString(scanner: *Scanner, quote: u8) HighlightError!void {
        const start = scanner.index;
        var cursor = start + 1;
        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == '\\') {
                const end = jsEscapeEnd(scanner.source, cursor);
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
        scanner.after_dot = false;
    }

    fn scanTemplate(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        var cursor = start + 1;
        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == '\\') {
                const end = jsEscapeEnd(scanner.source, cursor);
                try scanner.sink.add(cursor, end, .escape);
                cursor = end;
                continue;
            }
            if (cursor + 1 < scanner.source.len and scanner.source[cursor] == '$' and scanner.source[cursor + 1] == '{') {
                try scanner.sink.add(cursor, cursor + 2, .punctuation);
                cursor += 2;
                continue;
            }
            cursor += 1;
            if (scanner.source[cursor - 1] == '`') break;
        }
        try scanner.sink.add(start, cursor, .string);
        scanner.index = cursor;
        scanner.after_dot = false;
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
        scanner.after_dot = false;
    }

    fn scanOperator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and
            std.mem.indexOfScalar(u8, "+-*/%=!<>&|^~?:", scanner.source[scanner.index]) != null)
        {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .operator);
        scanner.after_dot = false;
    }

    fn scanIdentifier(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) scanner.index += 1;
        const word = scanner.source[start..scanner.index];
        if (scanner.next_identifier_scope) |scope| {
            try scanner.sink.add(start, scanner.index, scope);
            scanner.next_identifier_scope = null;
        } else if (isKeyword(word, scanner.typescript)) {
            try scanner.sink.add(start, scanner.index, .keyword);
            if (std.mem.eql(u8, word, "function")) scanner.next_identifier_scope = .function;
            if (std.mem.eql(u8, word, "class") or std.mem.eql(u8, word, "interface") or
                std.mem.eql(u8, word, "type") or std.mem.eql(u8, word, "enum"))
            {
                scanner.next_identifier_scope = .type;
            }
        } else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false")) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (std.mem.eql(u8, word, "null") or std.mem.eql(u8, word, "undefined") or
            std.mem.eql(u8, word, "NaN") or std.mem.eql(u8, word, "Infinity"))
        {
            try scanner.sink.add(start, scanner.index, .constant);
        } else if (isBuiltin(word)) {
            try scanner.sink.add(start, scanner.index, .builtin);
        } else if (scanner.typescript and isTypeKeyword(word)) {
            try scanner.sink.add(start, scanner.index, .builtin);
            try scanner.sink.add(start, scanner.index, .type);
        } else if (scanner.after_dot) {
            try scanner.sink.add(start, scanner.index, .property);
        } else {
            var next = scanner.index;
            while (next < scanner.source.len and std.ascii.isWhitespace(scanner.source[next])) next += 1;
            try scanner.sink.add(start, scanner.index, if (next < scanner.source.len and scanner.source[next] == '(') .function else .variable);
        }
        scanner.after_dot = false;
    }
};

fn jsEscapeEnd(source: []const u8, start: usize) usize {
    var end = @min(start + 2, source.len);
    if (start + 1 >= source.len) return end;
    const digits: usize = switch (source[start + 1]) {
        'x' => 2,
        'u' => 4,
        else => 0,
    };
    var consumed: usize = 0;
    while (end < source.len and consumed < digits and std.ascii.isHex(source[end])) : (consumed += 1) end += 1;
    return end;
}
fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_' or byte == '$';
}
fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$';
}
fn isKeyword(word: []const u8, typescript: bool) bool {
    const words = [_][]const u8{
        "as",      "async",  "await",  "break", "case",       "catch",   "class",   "const", "continue", "debugger",
        "default", "delete", "do",     "else",  "export",     "extends", "finally", "for",   "from",     "function",
        "get",     "if",     "import", "in",    "instanceof", "let",     "new",     "of",    "return",   "set",
        "static",  "super",  "switch", "this",  "throw",      "try",     "typeof",  "var",   "void",     "while",
        "with",    "yield",
    };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    if (typescript) {
        const ts_words = [_][]const u8{ "abstract", "declare", "enum", "implements", "interface", "keyof", "namespace", "private", "protected", "public", "readonly", "satisfies", "type", "unique", "unknown" };
        for (ts_words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    }
    return false;
}
fn isBuiltin(word: []const u8) bool {
    const words = [_][]const u8{ "Array", "BigInt", "Boolean", "Date", "Error", "JSON", "Map", "Math", "Number", "Object", "Promise", "Proxy", "Reflect", "RegExp", "Set", "String", "Symbol", "WeakMap", "WeakSet", "console", "globalThis" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
fn isTypeKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "any", "bigint", "boolean", "never", "number", "object", "string", "symbol", "unknown", "void" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
