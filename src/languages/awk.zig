const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "awk",
    .display_name = "AWK",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expect_operand: bool = true,
    expected_function: bool = false,
    awaiting_parameters: bool = false,
    parameter_depth: ?usize = null,
    paren_depth: usize = 0,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r' => parser.index += 1,
            '\n', ';' => {
                parser.expect_operand = true;
                parser.index += 1;
            },
            '#' => try parser.scanComment(),
            '"' => try parser.scanString(),
            '/' => if (parser.expect_operand) try parser.scanRegex() else try parser.scanOperator(),
            '$' => try parser.scanField(),
            '@' => try parser.scanDirective(),
            '0'...'9' => try parser.scanNumber(),
            '(' => {
                parser.paren_depth += 1;
                if (parser.awaiting_parameters) {
                    parser.parameter_depth = parser.paren_depth;
                    parser.awaiting_parameters = false;
                }
                parser.expect_operand = true;
                parser.index += 1;
            },
            ')' => {
                if (parser.parameter_depth == parser.paren_depth) parser.parameter_depth = null;
                parser.paren_depth -|= 1;
                parser.expect_operand = false;
                parser.index += 1;
            },
            '[', '{', ',' => {
                parser.expect_operand = true;
                parser.index += 1;
            },
            ']', '}' => {
                parser.expect_operand = false;
                parser.index += 1;
            },
            '+', '-', '*', '%', '^', '=', '!', '<', '>', '~', '?', ':', '&', '|' => try parser.scanOperator(),
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];

        if (parser.expected_function) {
            try parser.sink.add(start, parser.index, .function);
            parser.expected_function = false;
            parser.awaiting_parameters = true;
            parser.expect_operand = false;
            return;
        }
        if (std.mem.eql(u8, word, "function")) {
            try parser.sink.add(start, parser.index, .keyword);
            parser.expected_function = true;
            parser.expect_operand = true;
            return;
        }
        if (parser.parameter_depth != null and isParameterPosition(parser.source, start)) {
            try parser.sink.add(start, parser.index, .parameter);
            parser.expect_operand = false;
            return;
        }
        if (isKeyword(word)) {
            try parser.sink.add(start, parser.index, .keyword);
            parser.expect_operand = keywordExpectsOperand(word);
        } else if (isBuiltinFunction(word)) {
            try parser.sink.add(start, parser.index, .builtin);
            if (scanner.nextNonSpace(parser.source, parser.index) == '(') try parser.sink.add(start, parser.index, .function);
            parser.expect_operand = !std.mem.eql(u8, word, "getline");
        } else if (isBuiltinVariable(word)) {
            try parser.sink.add(start, parser.index, .builtin);
            parser.expect_operand = false;
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
            parser.expect_operand = false;
        } else {
            try parser.sink.add(start, parser.index, .variable);
            parser.expect_operand = false;
        }
    }

    fn scanString(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                const escape = parser.index;
                parser.index = scanner.escapeEnd(parser.source, parser.index);
                try parser.sink.add(escape, parser.index, .escape);
            } else {
                const byte = parser.source[parser.index];
                parser.index += 1;
                if (byte == '"' or byte == '\n') break;
            }
        }
        try parser.sink.add(start, parser.index, .string);
        parser.expect_operand = false;
    }

    fn scanRegex(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        var in_class = false;
        while (parser.index < parser.source.len) {
            const byte = parser.source[parser.index];
            if (byte == '\\') {
                const escape = parser.index;
                parser.index = scanner.escapeEnd(parser.source, parser.index);
                try parser.sink.add(escape, parser.index, .escape);
            } else {
                parser.index += 1;
                if (byte == '[') in_class = true;
                if (byte == ']') in_class = false;
                if (byte == '/' and !in_class) break;
                if (byte == '\n') break;
            }
        }
        try parser.sink.add(start, parser.index, .string);
        parser.expect_operand = false;
    }

    fn scanComment(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.lineEnd(parser.source, start, parser.source.len);
        try parser.sink.add(start, parser.index, .comment);
    }

    fn scanField(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (isIdentifierContinue(parser.source[parser.index]) or std.ascii.isDigit(parser.source[parser.index]))) parser.index += 1;
        try parser.sink.add(start, parser.index, .variable);
        parser.expect_operand = false;
    }

    fn scanDirective(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, parser.index, .attribute);
        parser.expect_operand = true;
    }

    fn scanNumber(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '.')) parser.index += 1;
        try parser.sink.add(start, parser.index, .number);
        parser.expect_operand = false;
    }

    fn scanOperator(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and std.mem.indexOfScalar(u8, "+-*/%^=!<>~?:&|", parser.source[parser.index]) != null) parser.index += 1;
        try parser.sink.add(start, parser.index, .operator);
        parser.expect_operand = true;
    }
};

fn isParameterPosition(source: []const u8, start: usize) bool {
    const previous = previousNonSpace(source, start) orelse return false;
    return previous == '(' or previous == ',';
}

const previousNonSpace = scanner.previousNonSpace;

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

const wordIs = scanner.wordIs;

fn isKeyword(word: []const u8) bool {
    return wordIs(word, &.{ "BEGIN", "BEGINFILE", "break", "case", "continue", "default", "delete", "do", "else", "END", "ENDFILE", "exit", "for", "if", "in", "next", "nextfile", "return", "switch", "while" });
}

fn keywordExpectsOperand(word: []const u8) bool {
    return wordIs(word, &.{ "case", "delete", "exit", "if", "return", "switch", "while" });
}

fn isBuiltinFunction(word: []const u8) bool {
    return wordIs(word, &.{ "and", "asort", "asorti", "atan2", "close", "compl", "cos", "exp", "fflush", "gensub", "getline", "gsub", "index", "int", "length", "log", "lshift", "match", "mktime", "or", "patsplit", "print", "printf", "rand", "rshift", "sin", "split", "sprintf", "sqrt", "srand", "strftime", "strtonum", "sub", "substr", "system", "systime", "tolower", "toupper", "xor" });
}

fn isBuiltinVariable(word: []const u8) bool {
    return wordIs(word, &.{ "ARGC", "ARGIND", "ARGV", "BINMODE", "CONVFMT", "ENVIRON", "ERRNO", "FIELDWIDTHS", "FILENAME", "FNR", "FPAT", "FS", "IGNORECASE", "LINT", "NF", "NR", "OFMT", "OFS", "ORS", "PREC", "PROCINFO", "RLENGTH", "ROUNDMODE", "RS", "RSTART", "RT", "SUBSEP", "SYMTAB", "TEXTDOMAIN" });
}
