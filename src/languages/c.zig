const std = @import("std");
const utf8 = @import("../utf8.zig");
const backend_api = @import("../backend.zig");
const nextNonSpace = @import("scanner_support.zig").nextNonSpace;
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "c",
    .display_name = "C",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    try scanner.run();
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
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
        }
    }
};

/// Tolerant declaration pass. It recognizes C's declaration boundaries and
/// derives roles that cannot be decided by spelling alone.
const StructureParser = struct {
    source: []const u8,
    sink: *CaptureSink,
    index: usize = 0,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    declaration: bool = false,
    typedef_declaration: bool = false,
    expect_tag: bool = false,
    pending_function: bool = false,

    fn run(parser: *StructureParser) HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r', '\n' => parser.index += 1,
            '#' => parser.skipPreprocessor(),
            '/' => {
                if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '/') {
                    parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len;
                } else if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '*') {
                    parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |end| end + 2 else parser.source.len;
                } else parser.index += 1;
            },
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            '(' => {
                parser.paren_depth += 1;
                if (parser.pending_function) {
                    parser.parameter_depth = parser.paren_depth;
                    parser.pending_function = false;
                }
                parser.index += 1;
            },
            ')' => {
                if (parser.parameter_depth == parser.paren_depth) parser.parameter_depth = null;
                parser.paren_depth -|= 1;
                parser.index += 1;
            },
            ';', '{', '}' => {
                parser.declaration = false;
                parser.typedef_declaration = false;
                parser.expect_tag = false;
                parser.pending_function = false;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanIdentifier(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn skipPreprocessor(parser: *StructureParser) void {
        while (parser.index < parser.source.len) {
            const newline = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse {
                parser.index = parser.source.len;
                return;
            };
            var before = newline;
            while (before > parser.index and (parser.source[before - 1] == ' ' or parser.source[before - 1] == '\t')) before -= 1;
            parser.index = newline + 1;
            if (before == 0 or parser.source[before - 1] != '\\') return;
        }
    }

    fn skipString(parser: *StructureParser, quote: u8) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == quote or byte == '\n') break;
        }
    }

    fn scanIdentifier(parser: *StructureParser) HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        const next = nextNonSpace(parser.source, parser.index);

        if (parser.expect_tag) {
            try parser.sink.add(start, parser.index, .type);
            parser.expect_tag = false;
            parser.declaration = true;
            return;
        }
        if (std.mem.eql(u8, word, "typedef")) {
            parser.typedef_declaration = true;
            parser.declaration = true;
            return;
        }
        if (std.mem.eql(u8, word, "struct") or std.mem.eql(u8, word, "union") or std.mem.eql(u8, word, "enum")) {
            parser.expect_tag = true;
            parser.declaration = true;
            return;
        }
        if (isType(word) or isTypeQualifier(word)) {
            parser.declaration = true;
            return;
        }
        if (isKeyword(word)) return;

        if (previousMemberOperator(parser.source, start)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (next == '(') {
            try parser.sink.add(start, parser.index, .function);
            if (parser.declaration) parser.pending_function = true;
            parser.declaration = false;
        } else if (next == ':' and parser.paren_depth == 0) {
            try parser.sink.add(start, parser.index, .label);
        } else if (parser.typedef_declaration and next == ';') {
            try parser.sink.add(start, parser.index, .type);
        } else if (parser.declaration or looksLikeType(word)) {
            if (looksLikeType(word) and next != ';' and next != ',' and next != '=') {
                try parser.sink.add(start, parser.index, .type);
                parser.declaration = true;
            } else {
                try parser.sink.add(start, parser.index, if (parser.parameter_depth != null) .parameter else .variable);
                if (next != ',') parser.declaration = false;
            }
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }
};

fn previousMemberOperator(source: []const u8, before: usize) bool {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return cursor > 0 and (source[cursor - 1] == '.' or
        (cursor > 1 and source[cursor - 2] == '-' and source[cursor - 1] == '>'));
}

fn looksLikeType(word: []const u8) bool {
    return word.len > 0 and std.ascii.isUpper(word[0]);
}

fn isTypeQualifier(word: []const u8) bool {
    const words = [_][]const u8{ "auto", "const", "extern", "inline", "register", "restrict", "static", "volatile", "_Atomic" };
    for (words) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}

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
    if (start + 1 >= source.len or source[start + 1] >= 0x80) {
        return utf8.escapedSequenceEnd(source, start, source.len);
    }
    var end = start + 2;
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
