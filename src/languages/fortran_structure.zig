const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const lexical = @import("fortran_scanner.zig");
const scanner = @import("scanner_support.zig");

const TokenKind = enum { word, l_paren, r_paren, comma, colon, percent, arrow, other };

const Token = struct {
    start: usize,
    end: usize,
    kind: TokenKind,
    role: ?Scope = null,
};

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    in_derived_type: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        var line_start: usize = 0;
        while (line_start < parser.source.len) {
            const line_end = scanner.lineEnd(parser.source, line_start, parser.source.len);
            try parser.scanLine(line_start, line_end);
            line_start = if (line_end < parser.source.len) line_end + 1 else parser.source.len;
        }
    }

    fn scanLine(parser: *Parser, line_start: usize, line_end: usize) api.HighlightError!void {
        if (line_start >= line_end or isFixedComment(parser.source[line_start..line_end])) return;

        var tokens: [128]Token = undefined;
        const count = tokenize(parser.source, line_start, line_end, &tokens);
        if (count == 0) return;
        const line = tokens[0..count];

        const first = firstWord(line) orelse return;
        const second = nextWord(line, first + 1);
        const is_end_type = wordEq(parser.source, line[first], "endtype") or
            (wordEq(parser.source, line[first], "end") and second != null and wordEq(parser.source, line[second.?], "type"));

        parser.markComponents(line);
        parser.markNamedStatement(line);
        parser.markDeclarations(line, first);
        parser.markCalls(line);

        for (line) |token| {
            if (token.kind != .word or ignoreLexicalWord(parser.source, token)) continue;
            if (token.role) |role| {
                try parser.sink.add(token.start, token.end, role);
            } else if (!lexical.isKeyword(parser.source[token.start..token.end]) and !lexical.isType(parser.source[token.start..token.end])) {
                try parser.sink.add(token.start, token.end, .variable);
            }
        }

        if (is_end_type) parser.in_derived_type = false;
    }

    fn markComponents(_: *Parser, tokens: []Token) void {
        for (tokens, 0..) |token, index| {
            if (token.kind == .percent) {
                if (nextWord(tokens, index + 1)) |member| tokens[member].role = .property;
            }
        }
    }

    fn markNamedStatement(parser: *Parser, tokens: []Token) void {
        if (tokens.len > 1 and tokens[0].kind == .word and tokens[1].kind == .colon) tokens[0].role = .label;

        for (tokens, 0..) |token, index| {
            if (token.kind != .word) continue;
            if (wordEq(parser.source, token, "call")) {
                if (nextWord(tokens, index + 1)) |name| tokens[name].role = .function;
            } else if (wordEq(parser.source, token, "result")) {
                if (wordInsideFollowingParens(tokens, index)) |name| tokens[name].role = .variable;
            }
        }
    }

    fn markCalls(parser: *Parser, tokens: []Token) void {
        for (tokens, 0..) |token, index| {
            if (token.kind != .word or lexical.isKeyword(parser.source[token.start..token.end]) or lexical.isType(parser.source[token.start..token.end])) continue;
            if (nextSignificant(tokens, index + 1)) |next| {
                if (tokens[next].kind == .l_paren and token.role == null) tokens[index].role = .function;
            }
        }
    }

    fn markDeclarations(parser: *Parser, tokens: []Token, first: usize) void {
        if (wordEq(parser.source, tokens[first], "end") or wordEq(parser.source, tokens[first], "endprogram") or
            wordEq(parser.source, tokens[first], "endmodule") or wordEq(parser.source, tokens[first], "endsubroutine") or
            wordEq(parser.source, tokens[first], "endfunction") or wordEq(parser.source, tokens[first], "endinterface") or
            wordEq(parser.source, tokens[first], "endtype"))
        {
            parser.markEndName(tokens, first);
            return;
        }

        if (wordEq(parser.source, tokens[first], "program")) {
            markNext(tokens, first + 1, .namespace);
            return;
        }
        if (wordEq(parser.source, tokens[first], "module")) {
            const name = nextWord(tokens, first + 1) orelse return;
            if (wordEq(parser.source, tokens[name], "procedure")) {
                markWordsAfter(tokens, name + 1, .function);
            } else {
                tokens[name].role = .namespace;
            }
            return;
        }
        if (wordEq(parser.source, tokens[first], "submodule")) {
            markWordsAfter(tokens, first + 1, .namespace);
            return;
        }
        if (wordEq(parser.source, tokens[first], "use")) {
            const separator = findKind(tokens, first + 1, .colon);
            markNext(tokens, if (separator) |index| index + 1 else first + 1, .namespace);
            return;
        }
        if (wordEq(parser.source, tokens[first], "interface")) {
            markNext(tokens, first + 1, .type);
            return;
        }

        if (findWord(parser.source, tokens, "subroutine")) |keyword| {
            if (nextWord(tokens, keyword + 1)) |name| {
                tokens[name].role = .function;
                markParameters(tokens, name);
            }
            return;
        }
        if (findWord(parser.source, tokens, "function")) |keyword| {
            if (nextWord(tokens, keyword + 1)) |name| {
                tokens[name].role = .function;
                markParameters(tokens, name);
            }
            return;
        }

        if (wordEq(parser.source, tokens[first], "type")) {
            if (wordInsideFollowingParens(tokens, first)) |name| {
                tokens[name].role = .type;
                parser.markVariableDeclaration(tokens, first);
            } else if (findKind(tokens, first + 1, .colon)) |separator| {
                if (nextWord(tokens, separator + 1)) |name| {
                    tokens[name].role = .type;
                    parser.in_derived_type = true;
                }
                if (findWord(parser.source, tokens, "extends")) |extends| {
                    if (wordInsideFollowingParens(tokens, extends)) |parent| tokens[parent].role = .type;
                }
            }
            return;
        }
        if (wordEq(parser.source, tokens[first], "class")) {
            if (wordInsideFollowingParens(tokens, first)) |name| tokens[name].role = .type;
            parser.markVariableDeclaration(tokens, first);
            return;
        }
        if (wordEq(parser.source, tokens[first], "procedure")) {
            if (wordInsideFollowingParens(tokens, first)) |interface_name| tokens[interface_name].role = .type;
            const separator = findKind(tokens, first + 1, .colon);
            markWordsAfter(tokens, if (separator) |index| index + 1 else first + 1, if (parser.in_derived_type) .property else .function);
            if (findKind(tokens, first + 1, .arrow)) |arrow| markWordsAfter(tokens, arrow + 1, .function);
            return;
        }
        if (lexical.isType(parser.source[tokens[first].start..tokens[first].end])) parser.markVariableDeclaration(tokens, first);
    }

    fn markVariableDeclaration(parser: *Parser, tokens: []Token, first: usize) void {
        const separator = findKind(tokens, first + 1, .colon);
        var start = if (separator) |index| index + 1 else first + 1;
        if (separator == null and wordEq(parser.source, tokens[first], "double")) {
            if (nextWord(tokens, start)) |precision| start = precision + 1;
        }
        for (tokens[start..]) |*token| {
            if (token.kind != .word or lexical.isKeyword(parser.source[token.start..token.end]) or lexical.isType(parser.source[token.start..token.end])) continue;
            if (token.role == null) token.role = if (parser.in_derived_type) .property else .variable;
        }
    }

    fn markEndName(parser: *Parser, tokens: []Token, first: usize) void {
        var cursor = first + 1;
        if (wordEq(parser.source, tokens[first], "end")) {
            const kind = nextWord(tokens, cursor) orelse return;
            cursor = kind + 1;
            const role: Scope = if (wordEq(parser.source, tokens[kind], "program") or wordEq(parser.source, tokens[kind], "module") or wordEq(parser.source, tokens[kind], "submodule")) .namespace else if (wordEq(parser.source, tokens[kind], "function") or wordEq(parser.source, tokens[kind], "subroutine")) .function else if (wordEq(parser.source, tokens[kind], "type") or wordEq(parser.source, tokens[kind], "interface")) .type else return;
            markNext(tokens, cursor, role);
            return;
        }
        const role: Scope = if (wordEq(parser.source, tokens[first], "endprogram") or wordEq(parser.source, tokens[first], "endmodule")) .namespace else if (wordEq(parser.source, tokens[first], "endfunction") or wordEq(parser.source, tokens[first], "endsubroutine")) .function else if (wordEq(parser.source, tokens[first], "endtype") or wordEq(parser.source, tokens[first], "endinterface")) .type else return;
        markNext(tokens, cursor, role);
    }
};

fn tokenize(source: []const u8, line_start: usize, line_end: usize, output: *[128]Token) usize {
    var count: usize = 0;
    var index = line_start;
    while (index < line_end and count < output.len) {
        const byte = source[index];
        if (byte == '!') break;
        if (byte == '\'' or byte == '"') {
            index = stringEnd(source, index, line_end, byte);
            continue;
        }
        if (scanner.isAsciiIdentifierStart(byte)) {
            const end = scanner.identifierEnd(source, index, .ascii);
            output[count] = .{ .start = index, .end = @min(end, line_end), .kind = .word };
            count += 1;
            index = end;
            continue;
        }
        const kind: TokenKind = switch (byte) {
            '(' => .l_paren,
            ')' => .r_paren,
            ',' => .comma,
            '%' => .percent,
            ':' => .colon,
            else => if (byte == '=' and index + 1 < line_end and source[index + 1] == '>') .arrow else .other,
        };
        const width: usize = if (kind == .colon and index + 1 < line_end and source[index + 1] == ':') 2 else if (kind == .arrow) 2 else 1;
        if (kind != .other) {
            output[count] = .{ .start = index, .end = index + width, .kind = kind };
            count += 1;
        }
        index += width;
    }
    return count;
}

fn stringEnd(source: []const u8, start: usize, limit: usize, quote: u8) usize {
    var index = start + 1;
    while (index < limit) {
        if (source[index] == quote) {
            if (index + 1 < limit and source[index + 1] == quote) {
                index += 2;
            } else {
                return index + 1;
            }
        } else {
            index += scanner.validUtf8Length(source[index..limit]);
        }
    }
    return limit;
}

fn isFixedComment(line: []const u8) bool {
    if (line.len == 0) return false;
    return line[0] == '!' or line[0] == '*' or ((line[0] == 'c' or line[0] == 'C') and line.len > 1 and std.ascii.isWhitespace(line[1]));
}

fn wordEq(source: []const u8, token: Token, expected: []const u8) bool {
    return token.kind == .word and std.ascii.eqlIgnoreCase(source[token.start..token.end], expected);
}

fn ignoreLexicalWord(source: []const u8, token: Token) bool {
    if (token.start > 0 and std.ascii.isDigit(source[token.start - 1])) return true;
    if (token.start > 0 and token.end < source.len and source[token.start - 1] == '.' and source[token.end] == '.') return true;
    const word = source[token.start..token.end];
    return word.len == 1 and (word[0] == 'b' or word[0] == 'B' or word[0] == 'o' or word[0] == 'O' or word[0] == 'z' or word[0] == 'Z') and
        token.end < source.len and (source[token.end] == '\'' or source[token.end] == '"');
}

fn firstWord(tokens: []const Token) ?usize {
    return nextWord(tokens, 0);
}

fn nextWord(tokens: []const Token, start: usize) ?usize {
    for (tokens[start..], start..) |token, index| if (token.kind == .word) return index;
    return null;
}

fn nextSignificant(tokens: []const Token, start: usize) ?usize {
    return if (start < tokens.len) start else null;
}

fn findWord(source: []const u8, tokens: []const Token, expected: []const u8) ?usize {
    for (tokens, 0..) |token, index| if (wordEq(source, token, expected)) return index;
    return null;
}

fn findKind(tokens: []const Token, start: usize, kind: TokenKind) ?usize {
    for (tokens[start..], start..) |token, index| if (token.kind == kind) return index;
    return null;
}

fn markNext(tokens: []Token, start: usize, role: Scope) void {
    if (nextWord(tokens, start)) |index| tokens[index].role = role;
}

fn markWordsAfter(tokens: []Token, start: usize, role: Scope) void {
    for (tokens[start..]) |*token| {
        if (token.kind == .word and token.role == null) token.role = role;
    }
}

fn wordInsideFollowingParens(tokens: []const Token, word: usize) ?usize {
    const open = nextSignificant(tokens, word + 1) orelse return null;
    if (tokens[open].kind != .l_paren) return null;
    return nextWord(tokens, open + 1);
}

fn markParameters(tokens: []Token, name: usize) void {
    const open = nextSignificant(tokens, name + 1) orelse return;
    if (tokens[open].kind != .l_paren) return;
    var depth: usize = 1;
    for (tokens[open + 1 ..]) |*token| {
        switch (token.kind) {
            .l_paren => depth += 1,
            .r_paren => {
                depth -= 1;
                if (depth == 0) return;
            },
            .word => {
                if (depth == 1 and token.role == null) token.role = .parameter;
            },
            else => {},
        }
    }
}
