const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "perl",
    .display_name = "Perl",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const keywords = &.{ "BEGIN", "CHECK", "END", "INIT", "UNITCHECK", "continue", "default", "do", "else", "elsif", "eval", "for", "foreach", "given", "goto", "if", "last", "local", "my", "next", "no", "our", "package", "redo", "require", "return", "state", "sub", "unless", "until", "use", "when", "while" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .keywords = keywords,
        .constants = &.{"undef"},
        .classify_identifiers = false,
        .identifier_dash = false,
        .at_scope = .variable,
    });
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    line_start: usize = 0,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    awaiting_parameters: bool = false,
    expected: ?Scope = null,
    expects_operand: bool = true,
    property_pending: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.onlyIndentBefore(parser.index) and parser.source[parser.index] == '=' and
                parser.index + 1 < parser.source.len and std.ascii.isAlphabetic(parser.source[parser.index + 1]))
            {
                try parser.scanPod();
                continue;
            }
            if (parser.onlyIndentBefore(parser.index) and
                (std.mem.startsWith(u8, parser.source[parser.index..], "__DATA__") or
                    std.mem.startsWith(u8, parser.source[parser.index..], "__END__")))
            {
                try parser.sink.add(parser.index, parser.source.len, .comment);
                parser.index = parser.source.len;
                continue;
            }
            if (parser.source[parser.index] == '<' and parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '<') {
                if (try parser.scanHeredoc()) continue;
            }
            if (try parser.scanQuoteLike()) continue;

            switch (parser.source[parser.index]) {
                '#' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
                '\'', '"', '`' => {
                    parser.index = scanner.quotedEnd(parser.source, parser.index, parser.source[parser.index], true);
                    parser.expects_operand = false;
                },
                '$', '@', '%' => try parser.scanVariable(),
                '/' => if (parser.expects_operand) {
                    try parser.scanBareRegex();
                } else {
                    parser.index += 1;
                    parser.expects_operand = true;
                },
                '(' => {
                    parser.paren_depth += 1;
                    if (parser.awaiting_parameters) {
                        parser.parameter_depth = parser.paren_depth;
                        parser.awaiting_parameters = false;
                    }
                    parser.index += 1;
                    parser.expects_operand = true;
                },
                ')' => {
                    if (parser.parameter_depth == parser.paren_depth) parser.parameter_depth = null;
                    parser.paren_depth -|= 1;
                    parser.index += 1;
                    parser.expects_operand = false;
                },
                '-' => {
                    if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '>') {
                        parser.property_pending = true;
                        parser.index += 2;
                    } else {
                        parser.index += 1;
                        parser.expects_operand = true;
                    }
                },
                '=' => {
                    parser.index += if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '>') 2 else 1;
                    parser.expects_operand = true;
                },
                ',', ';', '{', '[' => {
                    parser.index += 1;
                    parser.expects_operand = true;
                },
                '}', ']' => {
                    parser.index += 1;
                    parser.expects_operand = false;
                },
                '\n' => {
                    parser.index += 1;
                    parser.line_start = parser.index;
                    parser.expected = null;
                    parser.expects_operand = true;
                },
                '0'...'9' => parser.scanNumber(),
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        const word = parser.source[start..parser.index];

        if (parser.expected) |scope| {
            if (scope == .namespace) parser.index = qualifiedEnd(parser.source, start);
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            if (scope == .function) parser.awaiting_parameters = true;
            parser.expects_operand = false;
            return;
        }
        if (std.mem.eql(u8, word, "package")) {
            parser.expected = .namespace;
            parser.expects_operand = true;
            return;
        }
        if (wordIs(word, &.{ "use", "require", "no" })) {
            parser.expected = .namespace;
            parser.expects_operand = true;
            return;
        }
        if (std.mem.eql(u8, word, "sub")) {
            parser.expected = .function;
            parser.expects_operand = true;
            return;
        }
        if (isKeyword(word) or isLiteral(word)) {
            parser.expects_operand = wordIs(word, &.{ "return", "if", "unless", "while", "until", "for", "foreach", "given", "when" });
            return;
        }

        if (parser.property_pending) {
            try parser.sink.add(start, parser.index, .property);
            parser.property_pending = false;
        } else if (parser.onlyIndentBefore(start) and nextIsLabel(parser.source, parser.index)) {
            try parser.sink.add(start, parser.index, .label);
        } else if (nextIsFatComma(parser.source, parser.index)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (isBuiltin(word)) {
            try parser.sink.add(start, parser.index, .builtin);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (std.ascii.isUpper(word[0])) {
            parser.index = qualifiedEnd(parser.source, start);
            try parser.sink.add(start, parser.index, .type);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
        parser.expects_operand = false;
    }

    fn scanVariable(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '{') {
            parser.index += 1;
            while (parser.index < parser.source.len and parser.source[parser.index] != '}') {
                parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
            }
            if (parser.index < parser.source.len) parser.index += 1;
        } else if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        } else if (parser.index < parser.source.len) parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        try parser.sink.add(start, parser.index, .variable);
        if (parser.parameter_depth != null) try parser.sink.add(start, parser.index, .parameter);
        parser.expects_operand = false;
    }

    fn scanNumber(parser: *Parser) void {
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '_' or parser.source[parser.index] == '.')) parser.index += 1;
        parser.expects_operand = false;
    }

    fn scanBareRegex(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        parser.index = try parser.scanUntil(parser.index, '/');
        while (parser.index < parser.source.len and std.ascii.isAlphabetic(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, parser.index, .string);
        try parser.sink.add(start, start + 1, .special);
        parser.expects_operand = false;
    }

    fn scanQuoteLike(parser: *Parser) api.HighlightError!bool {
        const start = parser.index;
        if (start >= parser.source.len or !std.ascii.isAlphabetic(parser.source[start])) return false;
        const operator_len: usize = if (std.mem.startsWith(u8, parser.source[start..], "qq") or
            std.mem.startsWith(u8, parser.source[start..], "qw") or
            std.mem.startsWith(u8, parser.source[start..], "qx") or
            std.mem.startsWith(u8, parser.source[start..], "qr") or
            std.mem.startsWith(u8, parser.source[start..], "tr")) 2 else if (std.mem.indexOfScalar(u8, "qmsy", parser.source[start]) != null) 1 else return false;
        if (start + operator_len < parser.source.len and isIdentifierContinue(parser.source[start + operator_len])) return false;
        var delimiter = start + operator_len;
        while (delimiter < parser.source.len and (parser.source[delimiter] == ' ' or parser.source[delimiter] == '\t')) delimiter += 1;
        if (delimiter >= parser.source.len or std.ascii.isAlphanumeric(parser.source[delimiter]) or parser.source[delimiter] == '_') return false;

        const opening = parser.source[delimiter];
        const closing = scanner.matchingDelimiter(opening);
        parser.index = try parser.scanDelimited(delimiter, opening, closing);
        const replacement = (operator_len == 1 and (parser.source[start] == 's' or parser.source[start] == 'y')) or
            (operator_len == 2 and std.mem.eql(u8, parser.source[start .. start + 2], "tr"));
        if (replacement and parser.index < parser.source.len) {
            if (opening == closing) {
                parser.index = try parser.scanUntil(parser.index, closing);
            } else if (parser.source[parser.index] == opening) {
                parser.index = try parser.scanDelimited(parser.index, opening, closing);
            }
        }
        while (parser.index < parser.source.len and std.ascii.isAlphabetic(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, start + operator_len, .special);
        try parser.sink.add(start, parser.index, .string);
        parser.expects_operand = false;
        return true;
    }

    fn scanDelimited(parser: *Parser, opening_index: usize, opening: u8, closing: u8) api.HighlightError!usize {
        var index = opening_index + 1;
        var depth: usize = 1;
        while (index < parser.source.len) {
            if (parser.source[index] == '\\') {
                const escape_start = index;
                index = scanner.escapeEnd(parser.source, index);
                try parser.sink.add(escape_start, index, .escape);
            } else if (opening != closing and parser.source[index] == opening) {
                depth += 1;
                index += 1;
            } else if (parser.source[index] == closing) {
                depth -= 1;
                index += 1;
                if (depth == 0) return index;
            } else index += scanner.validUtf8Length(parser.source[index..]);
        }
        return index;
    }

    fn scanUntil(parser: *Parser, start: usize, closing: u8) api.HighlightError!usize {
        var index = start;
        while (index < parser.source.len) {
            if (parser.source[index] == '\\') {
                const escape_start = index;
                index = scanner.escapeEnd(parser.source, index);
                try parser.sink.add(escape_start, index, .escape);
            } else {
                const byte = parser.source[index];
                index += scanner.validUtf8Length(parser.source[index..]);
                if (byte == closing) break;
            }
        }
        return index;
    }

    fn scanHeredoc(parser: *Parser) api.HighlightError!bool {
        const start = parser.index;
        var index = start + 2;
        if (index < parser.source.len and parser.source[index] == '~') index += 1;
        while (index < parser.source.len and (parser.source[index] == ' ' or parser.source[index] == '\t')) index += 1;
        const quote: ?u8 = if (index < parser.source.len and (parser.source[index] == '\'' or parser.source[index] == '"' or parser.source[index] == '`')) parser.source[index] else null;
        if (quote != null) index += 1;
        const label_start = index;
        while (index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[index]) or parser.source[index] == '_')) index += 1;
        const label = parser.source[label_start..index];
        if (label.len == 0) return false;
        if (quote) |q| {
            if (index < parser.source.len and parser.source[index] == q) index += 1;
        }
        const opener_end = scanner.lineEnd(parser.source, index, parser.source.len);
        index = if (opener_end < parser.source.len) opener_end + 1 else opener_end;
        while (index < parser.source.len) {
            const line_end = scanner.lineEnd(parser.source, index, parser.source.len);
            var content = index;
            while (content < line_end and (parser.source[content] == ' ' or parser.source[content] == '\t')) content += 1;
            const content_end = if (line_end > content and parser.source[line_end - 1] == '\r') line_end - 1 else line_end;
            if (std.mem.eql(u8, parser.source[content..content_end], label)) {
                index = line_end;
                break;
            }
            index = if (line_end < parser.source.len) line_end + 1 else line_end;
        }
        try parser.sink.add(label_start, label_start + label.len, .label);
        try parser.sink.add(start, index, .string);
        parser.index = index;
        parser.expects_operand = false;
        return true;
    }

    fn scanPod(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        var index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
        while (index < parser.source.len) {
            index += 1;
            const line_end = scanner.lineEnd(parser.source, index, parser.source.len);
            if (std.mem.startsWith(u8, parser.source[index..line_end], "=cut")) {
                index = line_end;
                break;
            }
            index = line_end;
        }
        try parser.sink.add(start, index, .documentation);
        parser.index = index;
    }

    fn onlyIndentBefore(parser: Parser, position: usize) bool {
        return scanner.onlyIndentBefore(parser.source, parser.line_start, position);
    }
};

fn qualifiedEnd(source: []const u8, start: usize) usize {
    return scanner.qualifiedIdentifierEnd(source, start, "::", .ascii, .identifier);
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn nextIsLabel(source: []const u8, after: usize) bool {
    return scanner.nextNonSpace(source, after) == ':';
}

fn nextIsFatComma(source: []const u8, after: usize) bool {
    var index = after;
    while (index < source.len and std.ascii.isWhitespace(source[index]) and source[index] != '\n') index += 1;
    return index + 1 < source.len and source[index] == '=' and source[index + 1] == '>';
}

const wordIs = scanner.wordIs;

fn isKeyword(word: []const u8) bool {
    return wordIs(word, keywords);
}

fn isLiteral(word: []const u8) bool {
    return wordIs(word, &.{ "true", "false", "undef" });
}

fn isBuiltin(word: []const u8) bool {
    return wordIs(word, &.{ "chomp", "close", "defined", "die", "each", "exists", "grep", "join", "keys", "length", "map", "open", "pop", "print", "printf", "push", "ref", "say", "shift", "sort", "split", "sprintf", "unshift", "values", "warn" });
}
