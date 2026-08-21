const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "rust",
    .display_name = "Rust",
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
            if (scanner.startsWith("//")) {
                try scanner.scanLineComment();
            } else if (scanner.startsWith("/*")) {
                try scanner.scanBlockComment();
            } else if (scanner.source[scanner.index] == '#' and
                (scanner.startsWith("#[") or scanner.startsWith("#![")))
            {
                try scanner.scanAttribute();
            } else if (try scanner.scanPrefixedString()) {
                continue;
            } else switch (scanner.source[scanner.index]) {
                '"' => try scanner.scanCookedString(scanner.index, scanner.index),
                '\'' => try scanner.scanApostrophe(scanner.index, scanner.index),
                '0'...'9' => try scanner.scanNumber(),
                else => if (isIdentifierStart(scanner.source[scanner.index])) {
                    try scanner.scanIdentifier();
                } else if (isOperator(scanner.source[scanner.index])) {
                    try scanner.scanOperator();
                } else if (isPunctuation(scanner.source[scanner.index])) {
                    try scanner.sink.add(scanner.index, scanner.index + 1, .punctuation);
                    scanner.index += 1;
                } else {
                    scanner.index += 1;
                },
            }
        }
    }

    fn scanLineComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
        if (scanner.startsDocumentationComment(start)) {
            try scanner.sink.add(start, scanner.index, .documentation);
        }
    }

    fn scanBlockComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        var depth: usize = 1;
        scanner.index += 2;
        while (scanner.index < scanner.source.len and depth > 0) {
            if (scanner.startsWith("/*")) {
                depth += 1;
                scanner.index += 2;
            } else if (scanner.startsWith("*/")) {
                depth -= 1;
                scanner.index += 2;
            } else {
                scanner.index += 1;
            }
        }
        try scanner.sink.add(start, scanner.index, .comment);
        if (start + 2 < scanner.source.len and
            (scanner.source[start + 2] == '*' or scanner.source[start + 2] == '!'))
        {
            try scanner.sink.add(start, scanner.index, .documentation);
        }
    }

    fn scanAttribute(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        if (scanner.startsWith("#![")) scanner.index += 3 else scanner.index += 2;
        var depth: usize = 1;
        while (scanner.index < scanner.source.len and depth > 0) {
            const byte = scanner.source[scanner.index];
            if (byte == '"') {
                scanner.index = cookedStringEnd(scanner.source, scanner.index + 1);
            } else {
                if (byte == '[') depth += 1;
                if (byte == ']') depth -= 1;
                scanner.index += 1;
            }
        }
        try scanner.sink.add(start, scanner.index, .attribute);
    }

    fn scanPrefixedString(scanner: *Scanner) HighlightError!bool {
        const start = scanner.index;
        const byte = scanner.source[start];
        if (byte == 'r') {
            if (rawStringEnd(scanner.source, start + 1)) |end| {
                try scanner.sink.add(start, end, .string);
                scanner.index = end;
                return true;
            }
        }
        if ((byte == 'b' or byte == 'c') and start + 1 < scanner.source.len) {
            if (byte == 'b' and scanner.source[start + 1] == 'r') {
                if (rawStringEnd(scanner.source, start + 2)) |end| {
                    try scanner.sink.add(start, end, .string);
                    scanner.index = end;
                    return true;
                }
            }
            if (scanner.source[start + 1] == '"') {
                try scanner.scanCookedString(start, start + 1);
                return true;
            }
            if (byte == 'b' and scanner.source[start + 1] == '\'') {
                try scanner.scanApostrophe(start, start + 1);
                return true;
            }
        }
        return false;
    }

    fn scanCookedString(scanner: *Scanner, start: usize, quote_index: usize) HighlightError!void {
        var cursor = quote_index + 1;
        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == '\\') {
                const escape_end = @min(cursor + 2, scanner.source.len);
                try scanner.sink.add(cursor, escape_end, .escape);
                cursor = escape_end;
                continue;
            }
            cursor += 1;
            if (scanner.source[cursor - 1] == '"') break;
        }
        try scanner.sink.add(start, cursor, .string);
        scanner.index = cursor;
    }

    fn scanApostrophe(scanner: *Scanner, start: usize, quote_index: usize) HighlightError!void {
        const content_start = quote_index + 1;
        var cursor = content_start;
        if (cursor < scanner.source.len and scanner.source[cursor] == '\\') {
            const escape_end = @min(cursor + 2, scanner.source.len);
            try scanner.sink.add(cursor, escape_end, .escape);
            cursor = escape_end;
        } else if (cursor < scanner.source.len) {
            cursor += utf8SequenceLength(scanner.source[cursor]);
            cursor = @min(cursor, scanner.source.len);
        }

        if (cursor < scanner.source.len and scanner.source[cursor] == '\'') {
            scanner.index = cursor + 1;
            try scanner.sink.add(start, scanner.index, .string);
            return;
        }

        cursor = content_start;
        if (cursor < scanner.source.len and isIdentifierStart(scanner.source[cursor])) {
            cursor += 1;
            while (cursor < scanner.source.len and isIdentifierContinue(scanner.source[cursor])) cursor += 1;
            try scanner.sink.add(quote_index, cursor, .label);
            scanner.index = cursor;
            return;
        }
        scanner.index = quote_index + 1;
    }

    fn scanNumber(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            const byte = scanner.source[scanner.index];
            if (std.ascii.isAlphanumeric(byte) or byte == '_') {
                scanner.index += 1;
                continue;
            }
            if (byte == '.' and
                scanner.index + 1 < scanner.source.len and
                scanner.source[scanner.index + 1] != '.')
            {
                scanner.index += 1;
                continue;
            }
            if ((byte == '+' or byte == '-') and scanner.index > start and
                (scanner.source[scanner.index - 1] == 'e' or scanner.source[scanner.index - 1] == 'E'))
            {
                scanner.index += 1;
                continue;
            }
            break;
        }
        try scanner.sink.add(start, scanner.index, .number);
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
        } else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false")) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (isPrimitive(word)) {
            try scanner.sink.add(start, scanner.index, .builtin);
            try scanner.sink.add(start, scanner.index, .type);
        } else {
            var lookahead = scanner.index;
            while (lookahead < scanner.source.len and std.ascii.isWhitespace(scanner.source[lookahead])) {
                lookahead += 1;
            }
            if (lookahead < scanner.source.len and scanner.source[lookahead] == '!' and
                (lookahead + 1 >= scanner.source.len or scanner.source[lookahead + 1] != '='))
            {
                try scanner.sink.add(start, lookahead + 1, .macro);
                scanner.index = lookahead + 1;
            } else {
                try scanner.sink.add(start, scanner.index, .variable);
            }
        }
    }

    fn scanOperator(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isOperator(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn startsWith(scanner: Scanner, needle: []const u8) bool {
        return std.mem.startsWith(u8, scanner.source[scanner.index..], needle);
    }

    fn startsDocumentationComment(scanner: Scanner, start: usize) bool {
        return start + 2 < scanner.source.len and
            (scanner.source[start + 2] == '/' or scanner.source[start + 2] == '!');
    }
};

fn rawStringEnd(source: []const u8, marker_start: usize) ?usize {
    var quote = marker_start;
    while (quote < source.len and source[quote] == '#') quote += 1;
    if (quote >= source.len or source[quote] != '"') return null;
    const hashes = quote - marker_start;
    var cursor = quote + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] != '"') continue;
        if (cursor + 1 + hashes > source.len) continue;
        var matches = true;
        for (source[cursor + 1 .. cursor + 1 + hashes]) |byte| {
            if (byte != '#') matches = false;
        }
        if (matches) return cursor + 1 + hashes;
    }
    return source.len;
}

fn cookedStringEnd(source: []const u8, start: usize) usize {
    var cursor = start;
    while (cursor < source.len) {
        if (source[cursor] == '\\') {
            cursor = @min(cursor + 2, source.len);
            continue;
        }
        cursor += 1;
        if (source[cursor - 1] == '"') break;
    }
    return cursor;
}

fn utf8SequenceLength(byte: u8) usize {
    return if (byte < 0x80) 1 else if (byte < 0xe0) 2 else if (byte < 0xf0) 3 else 4;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isOperator(byte: u8) bool {
    return std.mem.indexOfScalar(u8, "+-*/%=!&|^<>?", byte) != null;
}

fn isPunctuation(byte: u8) bool {
    return std.mem.indexOfScalar(u8, "(){}[],:;.@#", byte) != null;
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "as",     "async", "await", "break",       "const", "continue", "crate",
        "dyn",    "else",  "enum",  "extern",      "fn",    "for",      "if",
        "impl",   "in",    "let",   "loop",        "match", "mod",      "move",
        "mut",    "pub",   "ref",   "return",      "self",  "Self",     "static",
        "struct", "super", "trait", "type",        "union", "unsafe",   "use",
        "where",  "while", "yield", "macro_rules",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) return true;
    }
    return false;
}

fn isPrimitive(word: []const u8) bool {
    const primitives = [_][]const u8{
        "bool", "char", "str", "i8",  "i16",  "i32",   "i64", "i128", "isize",
        "u8",   "u16",  "u32", "u64", "u128", "usize", "f32", "f64",
    };
    for (primitives) |primitive| {
        if (std.mem.eql(u8, word, primitive)) return true;
    }
    return false;
}
