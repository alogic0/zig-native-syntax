const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const scanner = @import("scanner_support.zig");

const keywords = &.{ "allocate", "allocatable", "associate", "asynchronous", "backspace", "bind", "block", "call", "case", "class", "close", "common", "contains", "continue", "critical", "cycle", "data", "deallocate", "dimension", "do", "else", "elseif", "elsewhere", "end", "endfile", "entry", "enum", "equivalence", "error", "exit", "extends", "external", "final", "flush", "forall", "format", "function", "generic", "go", "goto", "if", "implicit", "import", "in", "include", "inquire", "intent", "interface", "intrinsic", "module", "namelist", "none", "non_intrinsic", "only", "open", "operator", "optional", "parameter", "pause", "pointer", "print", "private", "procedure", "program", "protected", "public", "pure", "read", "recursive", "result", "return", "rewind", "save", "select", "sequence", "stop", "submodule", "subroutine", "sync", "target", "then", "type", "use", "value", "volatile", "wait", "where", "while", "write" };
const types = &.{ "character", "complex", "double", "integer", "logical", "precision", "real" };
const word_operators = &.{ "and", "eq", "eqv", "ge", "gt", "le", "lt", "ne", "neqv", "not", "or" };

pub const Mode = enum { complete, syntax_only };

pub fn highlight(source: []const u8, sink: *api.CaptureSink, mode: Mode) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink, .mode = mode };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    line_start: usize = 0,
    mode: Mode,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.index == parser.line_start) {
                if (parser.fixedCommentEnd()) |end| {
                    try parser.sink.add(parser.index, end, .comment);
                    parser.index = end;
                    continue;
                }
                try parser.scanStatementLabel();
                if (parser.index >= parser.source.len) break;
            }

            if (parser.source[parser.index] == '\n') {
                parser.index += 1;
                parser.line_start = parser.index;
                continue;
            }
            if (parser.isFixedContinuation()) {
                try parser.captureByte(.punctuation);
                continue;
            }
            if (parser.source[parser.index] == '!') {
                const end = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                try parser.sink.add(parser.index, end, .comment);
                parser.index = end;
                continue;
            }
            if (parser.source[parser.index] == '#' and scanner.onlyIndentBefore(parser.source, parser.line_start, parser.index)) {
                const end = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                try parser.sink.add(parser.index, end, .macro);
                parser.index = end;
                continue;
            }

            switch (parser.source[parser.index]) {
                '\'', '"' => try parser.scanString(),
                '0'...'9' => try parser.scanNumber(),
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                '.' => if (!try parser.scanDotWord()) try parser.captureByte(.operator),
                '(', ')', '[', ']', ',', ':', ';', '%' => try parser.captureByte(.punctuation),
                '+', '-', '*', '/', '=', '<', '>', '&' => try parser.scanOperator(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn fixedCommentEnd(parser: *const Parser) ?usize {
        const byte = parser.source[parser.index];
        if (byte == '!') return scanner.lineEnd(parser.source, parser.index, parser.source.len);
        if (byte == '*') return scanner.lineEnd(parser.source, parser.index, parser.source.len);
        if ((byte == 'c' or byte == 'C') and parser.index + 1 < parser.source.len and
            (parser.source[parser.index + 1] == ' ' or parser.source[parser.index + 1] == '\t' or parser.source[parser.index + 1] == '\n'))
        {
            return scanner.lineEnd(parser.source, parser.index, parser.source.len);
        }
        return null;
    }

    fn scanStatementLabel(parser: *Parser) api.HighlightError!void {
        var cursor = parser.line_start;
        while (cursor < parser.source.len and cursor - parser.line_start < 5 and parser.source[cursor] == ' ') cursor += 1;
        const start = cursor;
        while (cursor < parser.source.len and cursor - parser.line_start < 5 and std.ascii.isDigit(parser.source[cursor])) cursor += 1;
        if (cursor > start and (cursor - parser.line_start == 5 or cursor >= parser.source.len or std.ascii.isWhitespace(parser.source[cursor]))) {
            try parser.sink.add(start, cursor, .label);
            parser.index = cursor;
        }
    }

    fn isFixedContinuation(parser: *const Parser) bool {
        if (parser.index != parser.line_start + 5) return false;
        for (parser.source[parser.line_start..parser.index]) |byte| {
            if (byte != ' ' and !std.ascii.isDigit(byte)) return false;
        }
        const byte = parser.source[parser.index];
        return byte != ' ' and byte != '0' and byte != '\t' and byte != '\n' and byte != '\r';
    }

    fn scanString(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        const quote = parser.source[parser.index];
        parser.index += 1;
        while (parser.index < parser.source.len and parser.source[parser.index] != '\n') {
            if (parser.source[parser.index] == quote) {
                if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == quote) {
                    try parser.sink.add(parser.index, parser.index + 2, .escape);
                    parser.index += 2;
                    continue;
                }
                parser.index += 1;
                break;
            }
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        try parser.sink.add(start, parser.index, .string);
    }

    fn scanNumber(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        while (parser.index < parser.source.len and std.ascii.isDigit(parser.source[parser.index])) parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '.') {
            parser.index += 1;
            while (parser.index < parser.source.len and std.ascii.isDigit(parser.source[parser.index])) parser.index += 1;
        }
        if (parser.index < parser.source.len and (parser.source[parser.index] == 'e' or parser.source[parser.index] == 'E' or parser.source[parser.index] == 'd' or parser.source[parser.index] == 'D')) {
            parser.index += 1;
            if (parser.index < parser.source.len and (parser.source[parser.index] == '+' or parser.source[parser.index] == '-')) parser.index += 1;
            while (parser.index < parser.source.len and std.ascii.isDigit(parser.source[parser.index])) parser.index += 1;
        }
        if (parser.index < parser.source.len and parser.source[parser.index] == '_') {
            parser.index += 1;
            while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_')) parser.index += 1;
        }
        try parser.sink.add(start, parser.index, .number);
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        const word = parser.source[start..parser.index];

        if (word.len == 1 and (word[0] == 'b' or word[0] == 'B' or word[0] == 'o' or word[0] == 'O' or word[0] == 'z' or word[0] == 'Z') and
            parser.index < parser.source.len and (parser.source[parser.index] == '\'' or parser.source[parser.index] == '"'))
        {
            const quote = parser.source[parser.index];
            parser.index += 1;
            while (parser.index < parser.source.len and parser.source[parser.index] != quote and parser.source[parser.index] != '\n') parser.index += 1;
            if (parser.index < parser.source.len and parser.source[parser.index] == quote) parser.index += 1;
            try parser.sink.add(start, parser.index, .number);
        } else if (scanner.wordIsIgnoreCase(word, keywords)) {
            try parser.sink.add(start, parser.index, .keyword);
        } else if (scanner.wordIsIgnoreCase(word, types)) {
            try parser.sink.add(start, parser.index, .type);
        } else if (parser.mode == .syntax_only) {
            return;
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (scanner.previousNonSpace(parser.source, start) == '%') {
            try parser.sink.add(start, parser.index, .property);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanDotWord(parser: *Parser) api.HighlightError!bool {
        const start = parser.index;
        var end = start + 1;
        while (end < parser.source.len and std.ascii.isAlphabetic(parser.source[end])) end += 1;
        if (end == start + 1 or end >= parser.source.len or parser.source[end] != '.') return false;
        end += 1;
        const word = parser.source[start + 1 .. end - 1];
        parser.index = end;
        if (std.ascii.eqlIgnoreCase(word, "true") or std.ascii.eqlIgnoreCase(word, "false")) {
            try parser.sink.add(start, end, .boolean);
        } else if (scanner.wordIsIgnoreCase(word, word_operators)) {
            try parser.sink.add(start, end, .operator);
        } else {
            try parser.sink.add(start, end, .operator);
        }
        return true;
    }

    fn scanOperator(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        const two = if (start + 1 < parser.source.len) parser.source[start .. start + 2] else "";
        if (std.mem.eql(u8, two, "**") or std.mem.eql(u8, two, "//") or std.mem.eql(u8, two, "==") or
            std.mem.eql(u8, two, "/=") or std.mem.eql(u8, two, "<=") or std.mem.eql(u8, two, ">=") or
            std.mem.eql(u8, two, "=>") or std.mem.eql(u8, two, "::"))
        {
            parser.index += 2;
        } else {
            parser.index += 1;
        }
        try parser.sink.add(start, parser.index, if (parser.source[start] == '&') .punctuation else .operator);
    }

    fn captureByte(parser: *Parser, scope: Scope) api.HighlightError!void {
        try parser.sink.add(parser.index, parser.index + 1, scope);
        parser.index += 1;
    }
};

pub fn isKeyword(word: []const u8) bool {
    return scanner.wordIsIgnoreCase(word, keywords);
}

pub fn isType(word: []const u8) bool {
    return scanner.wordIsIgnoreCase(word, types);
}
