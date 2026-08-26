const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "python",
    .display_name = "Python",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

/// A tolerant event parser. It keeps enough delimiter and statement context to
/// assign structural roles without requiring syntactically complete input.
const Parser = struct {
    source: []const u8,
    sink: *CaptureSink,
    index: usize = 0,
    next_identifier_scope: ?Scope = null,
    previous_was_dot: bool = false,
    import_context: bool = false,
    signature_depth: ?usize = null,
    paren_depth: usize = 0,
    expect_parameter: bool = false,
    annotation: bool = false,

    fn run(scanner: *Parser) HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.source[scanner.index] == '#') {
                try scanner.scanComment();
            } else if (scanner.source[scanner.index] == '@') {
                try scanner.scanDecorator();
            } else if (stringPrefix(scanner.source, scanner.index)) |prefix| {
                try scanner.scanString(prefix);
            } else switch (scanner.source[scanner.index]) {
                '\n' => {
                    scanner.import_context = false;
                    scanner.previous_was_dot = false;
                    scanner.index += 1;
                },
                '0'...'9' => try scanner.scanNumber(),
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', ':' => try scanner.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', '.', ';' => try scanner.scanPunctuation(),
                else => if (isIdentifierStart(scanner.source[scanner.index])) {
                    try scanner.scanIdentifier();
                } else {
                    if (!std.ascii.isWhitespace(scanner.source[scanner.index])) scanner.previous_was_dot = false;
                    scanner.index += 1;
                },
            }
        }
    }

    fn captureByte(scanner: *Parser, scope: Scope) HighlightError!void {
        const byte = scanner.source[scanner.index];
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
        scanner.previous_was_dot = byte == '.';
    }

    fn scanPunctuation(scanner: *Parser) HighlightError!void {
        const byte = scanner.source[scanner.index];
        switch (byte) {
            '(' => {
                scanner.paren_depth += 1;
                if (scanner.signature_depth == scanner.paren_depth) {
                    scanner.expect_parameter = true;
                } else if (scanner.next_identifier_scope == null and scanner.signature_depth == null and
                    previousWordIs(scanner.source, scanner.index, "def"))
                {
                    scanner.signature_depth = scanner.paren_depth;
                    scanner.expect_parameter = true;
                }
            },
            ')' => {
                if (scanner.signature_depth == scanner.paren_depth) {
                    scanner.signature_depth = null;
                    scanner.expect_parameter = false;
                    scanner.annotation = false;
                }
                scanner.paren_depth -|= 1;
            },
            ',' => if (scanner.signature_depth == scanner.paren_depth) {
                scanner.expect_parameter = true;
                scanner.annotation = false;
            },
            else => {},
        }
        try scanner.captureByte(.punctuation);
    }

    fn scanComment(scanner: *Parser) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanDecorator(scanner: *Parser) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and
            (isIdentifierContinue(scanner.source[scanner.index]) or scanner.source[scanner.index] == '.'))
        {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .attribute);
    }

    fn scanString(scanner: *Parser, prefix: StringPrefix) HighlightError!void {
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

    fn scanNumber(scanner: *Parser) HighlightError!void {
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

    fn scanOperator(scanner: *Parser) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isOperatorByte(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .operator);
        const operator = scanner.source[start..scanner.index];
        if (scanner.signature_depth == scanner.paren_depth) {
            if (std.mem.eql(u8, operator, ":")) {
                scanner.annotation = true;
                scanner.expect_parameter = false;
            } else if (std.mem.indexOfScalar(u8, operator, '=') != null) {
                scanner.annotation = false;
            }
        } else if (std.mem.eql(u8, operator, "->")) {
            scanner.annotation = true;
        } else if (std.mem.eql(u8, operator, ":")) {
            scanner.annotation = false;
        }
        scanner.previous_was_dot = false;
    }

    fn scanIdentifier(scanner: *Parser) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        const word = scanner.source[start..scanner.index];
        if (scanner.next_identifier_scope) |scope| {
            try scanner.sink.add(start, scanner.index, scope);
            scanner.next_identifier_scope = null;
            if (scope == .function) {
                scanner.signature_depth = scanner.paren_depth + 1;
            }
        } else if (isKeyword(word)) {
            try scanner.sink.add(start, scanner.index, .keyword);
            if (std.mem.eql(u8, word, "def")) scanner.next_identifier_scope = .function;
            if (std.mem.eql(u8, word, "class")) scanner.next_identifier_scope = .type;
            if (std.mem.eql(u8, word, "import") or std.mem.eql(u8, word, "from")) scanner.import_context = true;
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
        } else if (scanner.previous_was_dot) {
            try scanner.sink.add(start, scanner.index, .property);
            if (nextNonSpaceByte(scanner.source, scanner.index) == '(') {
                try scanner.sink.add(start, scanner.index, .function);
            }
        } else if (scanner.signature_depth == scanner.paren_depth and scanner.expect_parameter) {
            try scanner.sink.add(start, scanner.index, .parameter);
            scanner.expect_parameter = false;
        } else if (scanner.annotation) {
            try scanner.sink.add(start, scanner.index, .type);
        } else if (scanner.import_context) {
            try scanner.sink.add(start, scanner.index, .namespace);
        } else if (nextNonSpaceByte(scanner.source, scanner.index) == '(') {
            if (std.ascii.isUpper(word[0])) {
                try scanner.sink.add(start, scanner.index, .constructor);
                try scanner.sink.add(start, scanner.index, .type);
            } else {
                try scanner.sink.add(start, scanner.index, .function);
            }
        } else {
            try scanner.sink.add(start, scanner.index, .variable);
        }
        scanner.previous_was_dot = false;
    }
};

fn previousWordIs(source: []const u8, before: usize, expected: []const u8) bool {
    var end = before;
    while (end > 0 and std.ascii.isWhitespace(source[end - 1])) end -= 1;
    var start = end;
    while (start > 0 and isIdentifierContinue(source[start - 1])) start -= 1;
    return std.mem.eql(u8, source[start..end], expected);
}

fn nextNonSpaceByte(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

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
    var length: usize = 1;
    if (start + 1 < source.len and isStringPrefixPair(source[start], source[start + 1])) length = 2;
    const quote_index = start + length;
    if (quote_index < source.len and (source[quote_index] == '"' or source[quote_index] == '\'')) {
        const first = std.ascii.toLower(source[start]);
        const second = if (length == 2) std.ascii.toLower(source[start + 1]) else 0;
        if (length == 1 and std.mem.indexOfScalar(u8, "rubf", first) == null) return null;
        return .{ .length = length, .raw = first == 'r' or second == 'r' };
    }
    return null;
}

fn isStringPrefixPair(first: u8, second: u8) bool {
    const pair = [2]u8{ std.ascii.toLower(first), std.ascii.toLower(second) };
    return std.mem.eql(u8, &pair, "br") or std.mem.eql(u8, &pair, "rb") or
        std.mem.eql(u8, &pair, "fr") or std.mem.eql(u8, &pair, "rf");
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
