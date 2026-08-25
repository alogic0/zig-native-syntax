const std = @import("std");
const utf8 = @import("../utf8.zig");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "sql",
    .display_name = "SQL",
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
            if (scanner.startsWith("--")) {
                try scanner.scanLineComment();
            } else if (scanner.startsWith("/*")) {
                try scanner.scanBlockComment();
            } else if (scanner.source[scanner.index] == '\'') {
                try scanner.scanQuoted('\'', .string);
            } else if (scanner.source[scanner.index] == '"' or scanner.source[scanner.index] == '`') {
                try scanner.scanQuoted(scanner.source[scanner.index], .property);
            } else if (scanner.source[scanner.index] == '[') {
                try scanner.scanBracketIdentifier();
            } else if (scanner.source[scanner.index] == '$' and try scanner.scanDollar()) {
                continue;
            } else switch (scanner.source[scanner.index]) {
                ':' => if (scanner.index + 1 < scanner.source.len and isIdentifierStart(scanner.source[scanner.index + 1])) {
                    try scanner.scanNamedParameter();
                } else try scanner.captureByte(.operator),
                '?' => try scanner.captureByte(.parameter),
                '0'...'9' => try scanner.scanNumber(),
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~' => try scanner.scanOperator(),
                '(', ')', ',', '.', ';' => try scanner.captureByte(.punctuation),
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
    }

    fn scanQuoted(scanner: *Scanner, quote: u8, scope: @import("../scope.zig").Scope) HighlightError!void {
        const start = scanner.index;
        var cursor = start + 1;
        while (cursor < scanner.source.len) {
            if (scanner.source[cursor] == quote) {
                if (cursor + 1 < scanner.source.len and scanner.source[cursor + 1] == quote) {
                    try scanner.sink.add(cursor, cursor + 2, .escape);
                    cursor += 2;
                    continue;
                }
                cursor += 1;
                break;
            }
            if (scope == .string and scanner.source[cursor] == '\\') {
                const end = utf8.escapedSequenceEnd(
                    scanner.source,
                    cursor,
                    scanner.source.len,
                );
                try scanner.sink.add(cursor, end, .escape);
                cursor = end;
                continue;
            }
            cursor += 1;
        }
        try scanner.sink.add(start, cursor, scope);
        scanner.index = cursor;
    }

    fn scanBracketIdentifier(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and scanner.source[scanner.index] != ']') scanner.index += 1;
        if (scanner.index < scanner.source.len) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .property);
    }

    fn scanDollar(scanner: *Scanner) HighlightError!bool {
        const start = scanner.index;
        var delimiter_end = start + 1;
        while (delimiter_end < scanner.source.len and
            (std.ascii.isAlphanumeric(scanner.source[delimiter_end]) or scanner.source[delimiter_end] == '_'))
        {
            delimiter_end += 1;
        }
        if (delimiter_end < scanner.source.len and scanner.source[delimiter_end] == '$') {
            const delimiter = scanner.source[start .. delimiter_end + 1];
            const end = if (std.mem.indexOfPos(u8, scanner.source, delimiter_end + 1, delimiter)) |closing|
                closing + delimiter.len
            else
                scanner.source.len;
            try scanner.sink.add(start, end, .string);
            scanner.index = end;
            return true;
        }
        if (start + 1 < scanner.source.len and std.ascii.isDigit(scanner.source[start + 1])) {
            scanner.index += 2;
            while (scanner.index < scanner.source.len and std.ascii.isDigit(scanner.source[scanner.index])) {
                scanner.index += 1;
            }
            try scanner.sink.add(start, scanner.index, .parameter);
            return true;
        }
        return false;
    }

    fn scanNamedParameter(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 2;
        while (scanner.index < scanner.source.len and isIdentifierContinue(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        try scanner.sink.add(start, scanner.index, .parameter);
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
        while (scanner.index < scanner.source.len and
            std.mem.indexOfScalar(u8, "+-*/%=!<>&|^~", scanner.source[scanner.index]) != null)
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
        } else if (std.ascii.eqlIgnoreCase(word, "true") or std.ascii.eqlIgnoreCase(word, "false")) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (std.ascii.eqlIgnoreCase(word, "null")) {
            try scanner.sink.add(start, scanner.index, .constant);
        } else {
            var next = scanner.index;
            while (next < scanner.source.len and std.ascii.isWhitespace(scanner.source[next])) next += 1;
            try scanner.sink.add(start, scanner.index, if (next < scanner.source.len and scanner.source[next] == '(') .function else .variable);
        }
    }
};

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}
fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$';
}
fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{
        "add",       "all",    "alter",    "and",        "as",     "asc",       "begin",    "between", "by",      "case",
        "check",     "column", "commit",   "constraint", "create", "cross",     "database", "default", "delete",  "desc",
        "distinct",  "drop",   "else",     "end",        "except", "exists",    "foreign",  "from",    "full",    "group",
        "having",    "in",     "index",    "inner",      "insert", "intersect", "into",     "is",      "join",    "key",
        "left",      "like",   "limit",    "not",        "on",     "or",        "order",    "outer",   "primary", "references",
        "returning", "right",  "rollback", "select",     "set",    "table",     "then",     "union",   "unique",  "update",
        "using",     "values", "view",     "when",       "where",  "with",
    };
    for (words) |candidate| if (std.ascii.eqlIgnoreCase(word, candidate)) return true;
    return false;
}
fn isType(word: []const u8) bool {
    const words = [_][]const u8{ "bigint", "binary", "blob", "boolean", "char", "date", "decimal", "double", "float", "int", "integer", "interval", "json", "numeric", "real", "smallint", "text", "time", "timestamp", "uuid", "varchar" };
    for (words) |candidate| if (std.ascii.eqlIgnoreCase(word, candidate)) return true;
    return false;
}
