//! Tolerant JavaScript and TypeScript syntax for contextual highlighting.
//!
//! This is a structural highlighting parser, not an ECMAScript validator. It
//! retains original byte ranges, recognizes declaration and expression roles,
//! and returns partial structure for incomplete source.

const std = @import("std");
const syntax = @import("../syntax.zig");

pub const Mode = enum { javascript, typescript };

pub const TokenTag = enum {
    eof,
    invalid,
    identifier,
    private_identifier,
    keyword,
    type_keyword,
    builtin,
    boolean,
    constant,
    number,
    string,
    template,
    comment,
    documentation_comment,
    l_paren,
    r_paren,
    l_bracket,
    r_bracket,
    l_brace,
    r_brace,
    comma,
    semicolon,
    dot,
    colon,
    operator,
};

pub const NodeTag = enum {
    root,
    variable_declaration,
    variable_binding,
    function_declaration,
    class_declaration,
    interface_declaration,
    type_alias_declaration,
    enum_declaration,
    parameter,
    call_expression,
    member_expression,
    type_reference,
};

pub const DiagnosticTag = enum {
    expected_identifier,
    expected_r_paren,
    unterminated_comment,
    unterminated_string,
    unterminated_template,
};

pub const Syntax = syntax.Model(TokenTag, NodeTag, DiagnosticTag);
pub const Tree = Syntax.Tree;
pub const ParseError = syntax.BuildError;

pub fn parse(allocator: std.mem.Allocator, source: []const u8, mode: Mode) ParseError!Tree {
    var builder = try Syntax.Builder.init(allocator, source.len);
    defer builder.deinit();

    try tokenize(source, mode, &builder);

    var parser: Parser = .{
        .source = source,
        .mode = mode,
        .builder = &builder,
        .cursor = .init(builder.tokens.items),
    };
    try parser.parseRoot();

    return builder.finish(source);
}

fn tokenize(source: []const u8, mode: Mode, builder: *Syntax.Builder) ParseError!void {
    var tokenizer: Tokenizer = .{
        .source = source,
        .mode = mode,
        .builder = builder,
    };
    try tokenizer.run();
}

const Tokenizer = struct {
    source: []const u8,
    mode: Mode,
    builder: *Syntax.Builder,
    index: usize = 0,

    fn run(tokenizer: *Tokenizer) ParseError!void {
        while (tokenizer.index < tokenizer.source.len) {
            const byte = tokenizer.source[tokenizer.index];
            if (std.ascii.isWhitespace(byte)) {
                tokenizer.index += 1;
            } else if (tokenizer.startsWith("//")) {
                try tokenizer.scanLineComment();
            } else if (tokenizer.startsWith("/*")) {
                try tokenizer.scanBlockComment();
            } else switch (byte) {
                '"', '\'' => try tokenizer.scanString(byte),
                '`' => try tokenizer.scanTemplate(),
                '0'...'9' => try tokenizer.scanNumber(),
                '(' => try tokenizer.captureByte(.l_paren),
                ')' => try tokenizer.captureByte(.r_paren),
                '[' => try tokenizer.captureByte(.l_bracket),
                ']' => try tokenizer.captureByte(.r_bracket),
                '{' => try tokenizer.captureByte(.l_brace),
                '}' => try tokenizer.captureByte(.r_brace),
                ',' => try tokenizer.captureByte(.comma),
                ';' => try tokenizer.captureByte(.semicolon),
                '.' => try tokenizer.captureByte(.dot),
                ':' => try tokenizer.captureByte(.colon),
                '#' => if (tokenizer.index + 1 < tokenizer.source.len and
                    isIdentifierStart(tokenizer.source[tokenizer.index + 1]))
                {
                    try tokenizer.scanPrivateIdentifier();
                } else {
                    try tokenizer.captureByte(.invalid);
                },
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', '?', '@' => try tokenizer.scanOperator(),
                else => if (isIdentifierStart(byte)) {
                    try tokenizer.scanIdentifier();
                } else if (byte >= 0x80) {
                    if (validUtf8SequenceLength(tokenizer.source[tokenizer.index..])) |len| {
                        tokenizer.index += len;
                    } else {
                        try tokenizer.captureByte(.invalid);
                    }
                } else {
                    try tokenizer.captureByte(.invalid);
                },
            }
        }
        _ = try tokenizer.builder.addToken(.eof, tokenizer.source.len, tokenizer.source.len);
    }

    fn startsWith(tokenizer: Tokenizer, text: []const u8) bool {
        return std.mem.startsWith(u8, tokenizer.source[tokenizer.index..], text);
    }

    fn captureByte(tokenizer: *Tokenizer, tag: TokenTag) ParseError!void {
        _ = try tokenizer.builder.addToken(tag, tokenizer.index, tokenizer.index + 1);
        tokenizer.index += 1;
    }

    fn scanLineComment(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index = std.mem.indexOfScalarPos(u8, tokenizer.source, start, '\n') orelse tokenizer.source.len;
        _ = try tokenizer.builder.addToken(.comment, start, tokenizer.index);
    }

    fn scanBlockComment(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        const documentation = start + 2 < tokenizer.source.len and tokenizer.source[start + 2] == '*';
        tokenizer.index += 2;
        while (tokenizer.index + 1 < tokenizer.source.len and !tokenizer.startsWith("*/")) {
            tokenizer.index += 1;
        }
        if (tokenizer.index + 1 < tokenizer.source.len) {
            tokenizer.index += 2;
        } else {
            tokenizer.index = tokenizer.source.len;
            try tokenizer.builder.addDiagnostic(.unterminated_comment, start);
        }
        _ = try tokenizer.builder.addToken(
            if (documentation) .documentation_comment else .comment,
            start,
            tokenizer.index,
        );
    }

    fn scanString(tokenizer: *Tokenizer, quote: u8) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        var terminated = false;
        while (tokenizer.index < tokenizer.source.len) {
            if (tokenizer.source[tokenizer.index] == '\\') {
                tokenizer.index = escapeEnd(tokenizer.source, tokenizer.index);
                continue;
            }
            const byte = tokenizer.source[tokenizer.index];
            tokenizer.index += 1;
            if (byte == quote) {
                terminated = true;
                break;
            }
            if (byte == '\n' or byte == '\r') break;
        }
        if (!terminated) try tokenizer.builder.addDiagnostic(.unterminated_string, start);
        _ = try tokenizer.builder.addToken(.string, start, tokenizer.index);
    }

    fn scanTemplate(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        var terminated = false;
        while (tokenizer.index < tokenizer.source.len) {
            if (tokenizer.source[tokenizer.index] == '\\') {
                tokenizer.index = escapeEnd(tokenizer.source, tokenizer.index);
                continue;
            }
            const byte = tokenizer.source[tokenizer.index];
            tokenizer.index += 1;
            if (byte == '`') {
                terminated = true;
                break;
            }
        }
        if (!terminated) try tokenizer.builder.addDiagnostic(.unterminated_template, start);
        _ = try tokenizer.builder.addToken(.template, start, tokenizer.index);
    }

    fn scanNumber(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len) {
            const byte = tokenizer.source[tokenizer.index];
            if (std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.') {
                tokenizer.index += 1;
            } else if ((byte == '+' or byte == '-') and tokenizer.index > start and
                (tokenizer.source[tokenizer.index - 1] == 'e' or tokenizer.source[tokenizer.index - 1] == 'E'))
            {
                tokenizer.index += 1;
            } else break;
        }
        _ = try tokenizer.builder.addToken(.number, start, tokenizer.index);
    }

    fn scanOperator(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len and isOperatorByte(tokenizer.source[tokenizer.index])) {
            tokenizer.index += 1;
        }
        _ = try tokenizer.builder.addToken(.operator, start, tokenizer.index);
    }

    fn scanPrivateIdentifier(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 2;
        while (tokenizer.index < tokenizer.source.len and isIdentifierContinue(tokenizer.source[tokenizer.index])) {
            tokenizer.index += 1;
        }
        _ = try tokenizer.builder.addToken(.private_identifier, start, tokenizer.index);
    }

    fn scanIdentifier(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len and isIdentifierContinue(tokenizer.source[tokenizer.index])) {
            tokenizer.index += 1;
        }
        const word = tokenizer.source[start..tokenizer.index];
        const tag: TokenTag = if (tokenizer.mode == .typescript and isTypeKeyword(word))
            .type_keyword
        else if (isKeyword(word, tokenizer.mode))
            .keyword
        else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false"))
            .boolean
        else if (std.mem.eql(u8, word, "null") or std.mem.eql(u8, word, "undefined") or
            std.mem.eql(u8, word, "NaN") or std.mem.eql(u8, word, "Infinity"))
            .constant
        else if (isBuiltin(word))
            .builtin
        else
            .identifier;
        _ = try tokenizer.builder.addToken(tag, start, tokenizer.index);
    }
};

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

const Parser = struct {
    source: []const u8,
    mode: Mode,
    builder: *Syntax.Builder,
    cursor: Syntax.Cursor,

    fn parseRoot(parser: *Parser) ParseError!void {
        while (parser.cursor.peekTag(0)) |tag| {
            if (tag == .eof) break;
            const token_index: syntax.TokenIndex = @intCast(parser.cursor.index);
            if (tag == .keyword) {
                const word = parser.tokenText(token_index);
                if (isOneOf(word, &.{ "const", "let", "var" })) {
                    try parser.parseVariableDeclaration(token_index);
                } else if (std.mem.eql(u8, word, "function")) {
                    try parser.parseFunctionDeclaration(token_index);
                } else if (std.mem.eql(u8, word, "class")) {
                    try parser.parseNamedDeclaration(token_index, .class_declaration);
                } else if (parser.mode == .typescript and std.mem.eql(u8, word, "interface")) {
                    try parser.parseNamedDeclaration(token_index, .interface_declaration);
                } else if (parser.mode == .typescript and std.mem.eql(u8, word, "type")) {
                    try parser.parseNamedDeclaration(token_index, .type_alias_declaration);
                } else if (parser.mode == .typescript and std.mem.eql(u8, word, "enum")) {
                    try parser.parseNamedDeclaration(token_index, .enum_declaration);
                } else if (parser.mode == .typescript and
                    isOneOf(word, &.{ "as", "extends", "implements", "satisfies" }))
                {
                    try parser.parseFollowingTypeReference(token_index);
                }
            } else if (tag == .identifier or tag == .private_identifier) {
                try parser.parseIdentifierExpression(token_index);
            } else if (parser.mode == .typescript and tag == .colon) {
                try parser.parseFollowingTypeReference(token_index);
            }
            _ = parser.cursor.advance();
        }

        const token_count: syntax.TokenIndex = @intCast(parser.builder.tokens.items.len);
        _ = try parser.builder.addNode(.root, 0, token_count, 0);
    }

    fn parseVariableDeclaration(parser: *Parser, keyword: syntax.TokenIndex) ParseError!void {
        const statement_end = parser.statementEnd(keyword + 1);
        var index = parser.nextSignificant(keyword + 1);
        var first_binding: ?syntax.TokenIndex = null;
        var delimiter_depth: usize = 0;
        var expect_binding = true;

        while (index < statement_end) : (index = parser.nextSignificant(index + 1)) {
            const tag = parser.tokenTag(index);
            switch (tag) {
                .l_paren, .l_bracket, .l_brace => delimiter_depth += 1,
                .r_paren, .r_bracket, .r_brace => if (delimiter_depth > 0) {
                    delimiter_depth -= 1;
                },
                .comma => if (delimiter_depth == 0) {
                    expect_binding = true;
                },
                .operator => if (delimiter_depth == 0 and std.mem.eql(u8, parser.tokenText(index), "=")) {
                    expect_binding = false;
                },
                .identifier => if (delimiter_depth == 0 and expect_binding) {
                    _ = try parser.builder.addNode(.variable_binding, index, index + 1, index);
                    if (first_binding == null) first_binding = index;
                    expect_binding = false;
                },
                else => {},
            }
        }

        if (first_binding) |binding| {
            _ = try parser.builder.addNode(.variable_declaration, keyword, statement_end, binding);
        } else {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenStart(keyword));
        }
    }

    fn parseFunctionDeclaration(parser: *Parser, keyword: syntax.TokenIndex) ParseError!void {
        const name = parser.nextSignificant(keyword + 1);
        if (parser.tokenTag(name) != .identifier) {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenEnd(keyword));
            return;
        }

        const l_paren = parser.findTag(name + 1, .l_paren, &.{ .l_brace, .semicolon, .eof });
        var declaration_end = name + 1;
        if (l_paren) |open| {
            const close = parser.matchingDelimiter(open, .l_paren, .r_paren);
            const params_end = close orelse parser.findTag(open + 1, .l_brace, &.{.eof}) orelse parser.eofIndex();
            try parser.parseParameters(open + 1, params_end);
            if (close) |close_index| {
                declaration_end = close_index + 1;
            } else {
                try parser.builder.addDiagnostic(.expected_r_paren, parser.tokenEnd(open));
                declaration_end = params_end;
            }
        }
        _ = try parser.builder.addNode(.function_declaration, keyword, declaration_end, name);
    }

    fn parseParameters(parser: *Parser, first: syntax.TokenIndex, last: syntax.TokenIndex) ParseError!void {
        var index = parser.nextSignificant(first);
        var depth: usize = 0;
        var expect_parameter = true;
        while (index < last) : (index = parser.nextSignificant(index + 1)) {
            const tag = parser.tokenTag(index);
            switch (tag) {
                .l_paren, .l_bracket, .l_brace => depth += 1,
                .r_paren, .r_bracket, .r_brace => if (depth > 0) {
                    depth -= 1;
                },
                .comma => if (depth == 0) {
                    expect_parameter = true;
                },
                .identifier => if (depth == 0 and expect_parameter) {
                    _ = try parser.builder.addNode(.parameter, index, index + 1, index);
                    expect_parameter = false;
                },
                else => {},
            }
        }
    }

    fn parseNamedDeclaration(
        parser: *Parser,
        keyword: syntax.TokenIndex,
        node_tag: NodeTag,
    ) ParseError!void {
        const name = parser.nextSignificant(keyword + 1);
        if (parser.tokenTag(name) != .identifier) {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenEnd(keyword));
            return;
        }
        _ = try parser.builder.addNode(node_tag, keyword, name + 1, name);
    }

    fn parseIdentifierExpression(parser: *Parser, identifier: syntax.TokenIndex) ParseError!void {
        const next = parser.nextSignificant(identifier + 1);
        if (parser.tokenTag(next) == .l_paren) {
            const last = if (parser.matchingDelimiter(next, .l_paren, .r_paren)) |close| close + 1 else next + 1;
            _ = try parser.builder.addNode(.call_expression, identifier, last, identifier);
        }

        const previous = parser.previousSignificant(identifier);
        if (previous) |previous_index| {
            if (parser.tokenTag(previous_index) == .dot) {
                _ = try parser.builder.addNode(.member_expression, previous_index, identifier + 1, identifier);
            }
        }
    }

    fn parseFollowingTypeReference(parser: *Parser, marker: syntax.TokenIndex) ParseError!void {
        const type_name = parser.nextSignificant(marker + 1);
        if (parser.tokenTag(type_name) == .identifier or parser.tokenTag(type_name) == .builtin) {
            _ = try parser.builder.addNode(.type_reference, type_name, type_name + 1, type_name);
        }
    }

    fn statementEnd(parser: Parser, first: syntax.TokenIndex) syntax.TokenIndex {
        var index = first;
        var depth: usize = 0;
        while (index < parser.builder.tokens.items.len) : (index += 1) {
            switch (parser.tokenTag(index)) {
                .l_paren, .l_bracket, .l_brace => depth += 1,
                .r_paren, .r_bracket, .r_brace => if (depth > 0) {
                    depth -= 1;
                },
                .semicolon => if (depth == 0) return index + 1,
                .eof => return index,
                else => {},
            }
        }
        return @intCast(parser.builder.tokens.items.len);
    }

    fn matchingDelimiter(
        parser: Parser,
        open: syntax.TokenIndex,
        open_tag: TokenTag,
        close_tag: TokenTag,
    ) ?syntax.TokenIndex {
        var depth: usize = 0;
        var index: usize = open;
        while (index < parser.builder.tokens.items.len) : (index += 1) {
            const tag = parser.builder.tokens.items[index].tag;
            if (tag == open_tag) {
                depth += 1;
            } else if (tag == close_tag) {
                depth -= 1;
                if (depth == 0) return @intCast(index);
            } else if (tag == .eof) {
                return null;
            }
        }
        return null;
    }

    fn findTag(
        parser: Parser,
        first: syntax.TokenIndex,
        wanted: TokenTag,
        stop_tags: []const TokenTag,
    ) ?syntax.TokenIndex {
        var index: usize = first;
        while (index < parser.builder.tokens.items.len) : (index += 1) {
            const tag = parser.builder.tokens.items[index].tag;
            if (tag == wanted) return @intCast(index);
            if (std.mem.indexOfScalar(TokenTag, stop_tags, tag) != null) return null;
        }
        return null;
    }

    fn nextSignificant(parser: Parser, first: syntax.TokenIndex) syntax.TokenIndex {
        var index: usize = first;
        while (index < parser.builder.tokens.items.len and isTrivia(parser.builder.tokens.items[index].tag)) {
            index += 1;
        }
        return @intCast(@min(index, parser.builder.tokens.items.len - 1));
    }

    fn previousSignificant(parser: Parser, token_index: syntax.TokenIndex) ?syntax.TokenIndex {
        var index: usize = token_index;
        while (index > 0) {
            index -= 1;
            if (!isTrivia(parser.builder.tokens.items[index].tag)) return @intCast(index);
        }
        return null;
    }

    fn tokenTag(parser: Parser, token_index: syntax.TokenIndex) TokenTag {
        return parser.builder.tokens.items[token_index].tag;
    }

    fn tokenText(parser: Parser, token_index: syntax.TokenIndex) []const u8 {
        return parser.builder.tokens.items[token_index].slice(parser.source);
    }

    fn tokenStart(parser: Parser, token_index: syntax.TokenIndex) usize {
        return parser.builder.tokens.items[token_index].start;
    }

    fn tokenEnd(parser: Parser, token_index: syntax.TokenIndex) usize {
        return parser.builder.tokens.items[token_index].end;
    }

    fn eofIndex(parser: Parser) syntax.TokenIndex {
        return @intCast(parser.builder.tokens.items.len - 1);
    }
};

fn isTrivia(tag: TokenTag) bool {
    return tag == .comment or tag == .documentation_comment;
}

fn escapeEnd(source: []const u8, start: usize) usize {
    const escaped_start = start + 1;
    if (escaped_start >= source.len) return source.len;
    if (source[escaped_start] >= 0x80) {
        return escaped_start + (validUtf8SequenceLength(source[escaped_start..]) orelse 1);
    }

    var end = escaped_start + 1;
    const digits: usize = switch (source[start + 1]) {
        'x' => 2,
        'u' => 4,
        else => 0,
    };
    var consumed: usize = 0;
    while (end < source.len and consumed < digits and std.ascii.isHex(source[end])) : (consumed += 1) {
        end += 1;
    }
    return end;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_' or byte == '$';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$';
}

fn isOperatorByte(byte: u8) bool {
    return std.mem.indexOfScalar(u8, "+-*/%=!<>&|^~?@", byte) != null;
}

fn isKeyword(word: []const u8, mode: Mode) bool {
    const words = [_][]const u8{
        "as",      "async",  "await",  "break", "case",       "catch",   "class",   "const", "continue", "debugger",
        "default", "delete", "do",     "else",  "export",     "extends", "finally", "for",   "from",     "function",
        "get",     "if",     "import", "in",    "instanceof", "let",     "new",     "of",    "return",   "set",
        "static",  "super",  "switch", "this",  "throw",      "try",     "typeof",  "var",   "void",     "while",
        "with",    "yield",
    };
    if (isOneOf(word, &words)) return true;
    if (mode == .typescript) {
        const ts_words = [_][]const u8{
            "abstract", "declare",   "enum",   "implements", "interface", "keyof", "namespace",
            "private",  "protected", "public", "readonly",   "satisfies", "type",  "unique",
            "unknown",
        };
        return isOneOf(word, &ts_words);
    }
    return false;
}

fn isBuiltin(word: []const u8) bool {
    const words = [_][]const u8{
        "Array",  "BigInt",  "Boolean", "Date",    "Error",      "JSON",   "Map", "Math",
        "Number", "Object",  "Promise", "Proxy",   "Reflect",    "RegExp", "Set", "String",
        "Symbol", "WeakMap", "WeakSet", "console", "globalThis",
    };
    return isOneOf(word, &words);
}

fn isTypeKeyword(word: []const u8) bool {
    const words = [_][]const u8{
        "any", "bigint", "boolean", "never", "number", "object", "string", "symbol", "unknown", "void",
    };
    return isOneOf(word, &words);
}

fn isOneOf(word: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| {
        if (std.mem.eql(u8, word, candidate)) return true;
    }
    return false;
}

test "JavaScript parser records declarations parameters calls and members" {
    const source =
        \\function greet(name) { return api.run(name); }
        \\const answer = greet("world");
    ;
    var tree = try parse(std.testing.allocator, source, .javascript);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .function_declaration, "greet");
    try expectNodeMain(&tree, .parameter, "name");
    try expectNodeMain(&tree, .member_expression, "run");
    try expectNodeMain(&tree, .call_expression, "run");
    try expectNodeMain(&tree, .variable_binding, "answer");
    try std.testing.expectEqual(@as(usize, 0), tree.diagnostics.len);
    try tree.validate();
}

test "TypeScript parser records declarations and type references" {
    const source =
        \\interface User { name: string }
        \\type UserList = Array<User>;
        \\function first(values: UserList): User { return values[0]; }
    ;
    var tree = try parse(std.testing.allocator, source, .typescript);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .interface_declaration, "User");
    try expectNodeMain(&tree, .type_alias_declaration, "UserList");
    try expectNodeMain(&tree, .type_reference, "UserList");
    try std.testing.expectEqual(@as(usize, 0), tree.diagnostics.len);
    try tree.validate();
}

test "parser returns partial structure and diagnostics for incomplete source" {
    const source = "function broken(value { service.run(`unfinished";
    var tree = try parse(std.testing.allocator, source, .javascript);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .function_declaration, "broken");
    try expectNodeMain(&tree, .parameter, "value");
    try expectNodeMain(&tree, .member_expression, "run");
    try std.testing.expect(tree.diagnostics.len >= 2);
    try tree.validate();
}

test "JavaScript parser output is deterministic" {
    const source = "function broken(value { service.run(`unfinished";
    var first = try parse(std.testing.allocator, source, .javascript);
    defer first.deinit(std.testing.allocator);
    var second = try parse(std.testing.allocator, source, .javascript);
    defer second.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(Syntax.Token, first.tokens, second.tokens);
    try std.testing.expectEqualSlices(Syntax.Node, first.nodes, second.nodes);
    try std.testing.expectEqualSlices(Syntax.Diagnostic, first.diagnostics, second.diagnostics);
}

fn expectNodeMain(tree: *const Tree, tag: NodeTag, expected: []const u8) !void {
    for (tree.nodes) |node| {
        if (node.tag == tag and std.mem.eql(u8, tree.tokenSlice(node.main_token), expected)) return;
    }
    return error.TestExpectedEqual;
}
