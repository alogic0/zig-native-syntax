//! Tolerant Rust syntax for contextual highlighting.
//!
//! The parser recognizes a bounded structural subset and preserves exact byte
//! ranges for incomplete input. It is not a Rust validator, macro expander,
//! name resolver, or edition-specific grammar implementation.

const std = @import("std");
const syntax = @import("../syntax.zig");

pub const TokenTag = enum {
    eof,
    invalid,
    identifier,
    keyword,
    boolean,
    primitive_type,
    number,
    string,
    lifetime,
    comment,
    documentation_comment,
    attribute,
    macro,
    operator,
    punctuation,
};

pub const NodeTag = enum {
    root,
    function_declaration,
    parameter,
    type_declaration,
    type_alias_declaration,
    module_declaration,
    constant_declaration,
    static_declaration,
    variable_binding,
    field_declaration,
    enum_variant,
    call_expression,
    member_expression,
    type_reference,
    impl_target,
};

pub const DiagnosticTag = enum {
    expected_identifier,
    expected_r_paren,
    expected_r_brace,
    unterminated_comment,
    unterminated_string,
    unterminated_attribute,
};

pub const Syntax = syntax.Model(TokenTag, NodeTag, DiagnosticTag);
pub const Tree = Syntax.Tree;
pub const ParseError = syntax.BuildError;

pub fn parse(allocator: std.mem.Allocator, source: []const u8) ParseError!Tree {
    var builder = try Syntax.Builder.init(allocator, source.len);
    defer builder.deinit();

    try tokenize(source, &builder);
    var parser: Parser = .{
        .source = source,
        .builder = &builder,
        .cursor = .init(builder.tokens.items),
    };
    try parser.parseRoot();
    return builder.finish(source);
}

fn tokenize(source: []const u8, builder: *Syntax.Builder) ParseError!void {
    var tokenizer: Tokenizer = .{ .source = source, .builder = builder };
    try tokenizer.run();
    _ = try builder.addToken(.eof, source.len, source.len);
}

const Tokenizer = struct {
    source: []const u8,
    builder: *Syntax.Builder,
    index: usize = 0,

    fn run(tokenizer: *Tokenizer) ParseError!void {
        while (tokenizer.index < tokenizer.source.len) {
            if (std.ascii.isWhitespace(tokenizer.source[tokenizer.index])) {
                tokenizer.index += 1;
            } else if (tokenizer.startsWith("//")) {
                try tokenizer.scanLineComment();
            } else if (tokenizer.startsWith("/*")) {
                try tokenizer.scanBlockComment();
            } else if (tokenizer.source[tokenizer.index] == '#' and
                (tokenizer.startsWith("#[") or tokenizer.startsWith("#![")))
            {
                try tokenizer.scanAttribute();
            } else if (try tokenizer.scanPrefixedString()) {
                continue;
            } else switch (tokenizer.source[tokenizer.index]) {
                '"' => try tokenizer.scanCookedString(tokenizer.index, tokenizer.index),
                '\'' => try tokenizer.scanApostrophe(tokenizer.index, tokenizer.index),
                '0'...'9' => try tokenizer.scanNumber(),
                else => if (isIdentifierStart(tokenizer.source[tokenizer.index])) {
                    try tokenizer.scanIdentifier();
                } else if (isOperator(tokenizer.source[tokenizer.index])) {
                    try tokenizer.scanOperator();
                } else if (isPunctuation(tokenizer.source[tokenizer.index])) {
                    const start = tokenizer.index;
                    tokenizer.index += 1;
                    _ = try tokenizer.builder.addToken(.punctuation, start, tokenizer.index);
                } else {
                    const start = tokenizer.index;
                    tokenizer.index += 1;
                    _ = try tokenizer.builder.addToken(.invalid, start, tokenizer.index);
                },
            }
        }
    }

    fn scanLineComment(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index = std.mem.indexOfScalarPos(u8, tokenizer.source, start, '\n') orelse
            tokenizer.source.len;
        const tag: TokenTag = if (tokenizer.startsDocumentationComment(start))
            .documentation_comment
        else
            .comment;
        _ = try tokenizer.builder.addToken(tag, start, tokenizer.index);
    }

    fn scanBlockComment(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        var depth: usize = 1;
        tokenizer.index += 2;
        while (tokenizer.index < tokenizer.source.len and depth > 0) {
            if (tokenizer.startsWith("/*")) {
                depth += 1;
                tokenizer.index += 2;
            } else if (tokenizer.startsWith("*/")) {
                depth -= 1;
                tokenizer.index += 2;
            } else {
                tokenizer.index += 1;
            }
        }
        if (depth > 0) try tokenizer.builder.addDiagnostic(.unterminated_comment, start);
        const documentation = start + 2 < tokenizer.source.len and
            (tokenizer.source[start + 2] == '*' or tokenizer.source[start + 2] == '!');
        _ = try tokenizer.builder.addToken(
            if (documentation) .documentation_comment else .comment,
            start,
            tokenizer.index,
        );
    }

    fn scanAttribute(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        if (tokenizer.startsWith("#![")) tokenizer.index += 3 else tokenizer.index += 2;
        var depth: usize = 1;
        while (tokenizer.index < tokenizer.source.len and depth > 0) {
            const byte = tokenizer.source[tokenizer.index];
            if (byte == '"') {
                tokenizer.index = cookedStringEnd(tokenizer.source, tokenizer.index + 1).end;
            } else {
                if (byte == '[') depth += 1;
                if (byte == ']') depth -= 1;
                tokenizer.index += 1;
            }
        }
        if (depth > 0) try tokenizer.builder.addDiagnostic(.unterminated_attribute, start);
        _ = try tokenizer.builder.addToken(.attribute, start, tokenizer.index);
    }

    fn scanPrefixedString(tokenizer: *Tokenizer) ParseError!bool {
        const start = tokenizer.index;
        const byte = tokenizer.source[start];
        if (byte == 'r') {
            if (rawStringEnd(tokenizer.source, start + 1)) |result| {
                if (!result.terminated) try tokenizer.builder.addDiagnostic(.unterminated_string, start);
                _ = try tokenizer.builder.addToken(.string, start, result.end);
                tokenizer.index = result.end;
                return true;
            }
        }
        if ((byte == 'b' or byte == 'c') and start + 1 < tokenizer.source.len) {
            if (byte == 'b' and tokenizer.source[start + 1] == 'r') {
                if (rawStringEnd(tokenizer.source, start + 2)) |result| {
                    if (!result.terminated) try tokenizer.builder.addDiagnostic(.unterminated_string, start);
                    _ = try tokenizer.builder.addToken(.string, start, result.end);
                    tokenizer.index = result.end;
                    return true;
                }
            }
            if (tokenizer.source[start + 1] == '"') {
                try tokenizer.scanCookedString(start, start + 1);
                return true;
            }
            if (byte == 'b' and tokenizer.source[start + 1] == '\'') {
                try tokenizer.scanApostrophe(start, start + 1);
                return true;
            }
        }
        return false;
    }

    fn scanCookedString(tokenizer: *Tokenizer, start: usize, quote_index: usize) ParseError!void {
        const result = cookedStringEnd(tokenizer.source, quote_index + 1);
        if (!result.terminated) try tokenizer.builder.addDiagnostic(.unterminated_string, start);
        _ = try tokenizer.builder.addToken(.string, start, result.end);
        tokenizer.index = result.end;
    }

    fn scanApostrophe(tokenizer: *Tokenizer, start: usize, quote_index: usize) ParseError!void {
        const content_start = quote_index + 1;
        var cursor = content_start;
        if (cursor < tokenizer.source.len and tokenizer.source[cursor] == '\\') {
            cursor = @min(cursor + 2, tokenizer.source.len);
        } else if (cursor < tokenizer.source.len) {
            cursor = @min(cursor + utf8SequenceLength(tokenizer.source[cursor]), tokenizer.source.len);
        }

        if (cursor < tokenizer.source.len and tokenizer.source[cursor] == '\'') {
            tokenizer.index = cursor + 1;
            _ = try tokenizer.builder.addToken(.string, start, tokenizer.index);
            return;
        }

        cursor = content_start;
        if (cursor < tokenizer.source.len and isIdentifierStart(tokenizer.source[cursor])) {
            cursor += 1;
            while (cursor < tokenizer.source.len and isIdentifierContinue(tokenizer.source[cursor])) {
                cursor += 1;
            }
            _ = try tokenizer.builder.addToken(.lifetime, quote_index, cursor);
            tokenizer.index = cursor;
            return;
        }

        tokenizer.index = quote_index + 1;
        _ = try tokenizer.builder.addToken(.invalid, start, tokenizer.index);
    }

    fn scanNumber(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len) {
            const byte = tokenizer.source[tokenizer.index];
            if (std.ascii.isAlphanumeric(byte) or byte == '_') {
                tokenizer.index += 1;
            } else if (byte == '.' and
                tokenizer.index + 1 < tokenizer.source.len and
                tokenizer.source[tokenizer.index + 1] != '.')
            {
                tokenizer.index += 1;
            } else if ((byte == '+' or byte == '-') and tokenizer.index > start and
                (tokenizer.source[tokenizer.index - 1] == 'e' or
                    tokenizer.source[tokenizer.index - 1] == 'E'))
            {
                tokenizer.index += 1;
            } else break;
        }
        _ = try tokenizer.builder.addToken(.number, start, tokenizer.index);
    }

    fn scanIdentifier(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len and
            isIdentifierContinue(tokenizer.source[tokenizer.index]))
        {
            tokenizer.index += 1;
        }

        const word = tokenizer.source[start..tokenizer.index];
        const tag: TokenTag = if (isKeyword(word))
            .keyword
        else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false"))
            .boolean
        else if (isPrimitive(word))
            .primitive_type
        else blk: {
            var lookahead = tokenizer.index;
            while (lookahead < tokenizer.source.len and std.ascii.isWhitespace(tokenizer.source[lookahead])) {
                lookahead += 1;
            }
            if (lookahead < tokenizer.source.len and tokenizer.source[lookahead] == '!' and
                (lookahead + 1 >= tokenizer.source.len or tokenizer.source[lookahead + 1] != '='))
            {
                tokenizer.index = lookahead + 1;
                break :blk .macro;
            }
            break :blk .identifier;
        };
        _ = try tokenizer.builder.addToken(tag, start, tokenizer.index);
    }

    fn scanOperator(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len and isOperator(tokenizer.source[tokenizer.index])) {
            tokenizer.index += 1;
        }
        _ = try tokenizer.builder.addToken(.operator, start, tokenizer.index);
    }

    fn startsWith(tokenizer: Tokenizer, needle: []const u8) bool {
        return std.mem.startsWith(u8, tokenizer.source[tokenizer.index..], needle);
    }

    fn startsDocumentationComment(tokenizer: Tokenizer, start: usize) bool {
        return start + 2 < tokenizer.source.len and
            (tokenizer.source[start + 2] == '/' or tokenizer.source[start + 2] == '!');
    }
};

const Parser = struct {
    source: []const u8,
    builder: *Syntax.Builder,
    cursor: Syntax.Cursor,

    fn parseRoot(parser: *Parser) ParseError!void {
        while (parser.cursor.peekTag(0)) |tag| {
            if (tag == .eof) break;
            const token_index = parser.cursor.advance().?;
            if (tag == .keyword) try parser.parseKeyword(token_index);
        }

        try parser.parseExpressions();
        const token_count: syntax.TokenIndex = @intCast(parser.builder.tokens.items.len);
        _ = try parser.builder.addNode(.root, 0, token_count, 0);
    }

    fn parseKeyword(parser: *Parser, keyword: syntax.TokenIndex) ParseError!void {
        const text = parser.tokenText(keyword);
        if (std.mem.eql(u8, text, "fn")) {
            try parser.parseFunction(keyword);
        } else if (std.mem.eql(u8, text, "struct") or
            std.mem.eql(u8, text, "union") or
            std.mem.eql(u8, text, "enum") or
            std.mem.eql(u8, text, "trait"))
        {
            try parser.parseTypeDeclaration(keyword, std.mem.eql(u8, text, "enum"));
        } else if (std.mem.eql(u8, text, "type")) {
            try parser.parseNamedDeclaration(keyword, .type_alias_declaration);
        } else if (std.mem.eql(u8, text, "mod")) {
            try parser.parseNamedDeclaration(keyword, .module_declaration);
        } else if (std.mem.eql(u8, text, "const")) {
            try parser.parseValueDeclaration(keyword, .constant_declaration);
        } else if (std.mem.eql(u8, text, "static")) {
            try parser.parseValueDeclaration(keyword, .static_declaration);
        } else if (std.mem.eql(u8, text, "let")) {
            try parser.parseValueDeclaration(keyword, .variable_binding);
        } else if (std.mem.eql(u8, text, "impl")) {
            try parser.parseImpl(keyword);
        }
    }

    fn parseFunction(parser: *Parser, keyword: syntax.TokenIndex) ParseError!void {
        const name = parser.nextCode(keyword + 1);
        if (parser.tokenTag(name) != .identifier) {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenEnd(keyword));
            return;
        }
        _ = try parser.builder.addNode(.function_declaration, keyword, name + 1, name);

        const open = parser.findText(name + 1, "(") orelse return;
        const close = parser.matchingClose(open, "(", ")") orelse {
            try parser.builder.addDiagnostic(.expected_r_paren, parser.tokenEnd(open));
            try parser.parseParameters(open + 1, parser.eofIndex());
            return;
        };
        try parser.parseParameters(open + 1, close);

        const arrow = parser.nextCode(close + 1);
        if (parser.tokenIs(arrow, "->")) {
            const end = parser.findTypeBoundary(arrow + 1, &.{ "{", ";", "where" });
            try parser.addTypeReferences(arrow + 1, end);
        }
    }

    fn parseParameters(parser: *Parser, first: syntax.TokenIndex, last: syntax.TokenIndex) ParseError!void {
        var segment_start = first;
        var index = first;
        var nesting: Nesting = .{};
        while (index <= last) : (index += 1) {
            const at_end = index == last;
            if (!at_end and !(nesting.isZero() and parser.tokenIs(index, ","))) {
                nesting.update(parser.tokenText(index));
                continue;
            }

            const segment_end = index;
            const colon = parser.findTextBefore(segment_start, segment_end, ":");
            const binding_limit = colon orelse segment_end;
            if (parser.findBinding(segment_start, binding_limit)) |binding| {
                _ = try parser.builder.addNode(.parameter, segment_start, segment_end, binding);
            }
            if (colon) |marker| try parser.addTypeReferences(marker + 1, segment_end);
            segment_start = index + 1;
        }
    }

    fn parseTypeDeclaration(
        parser: *Parser,
        keyword: syntax.TokenIndex,
        is_enum: bool,
    ) ParseError!void {
        const name = parser.nextCode(keyword + 1);
        if (parser.tokenTag(name) != .identifier) {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenEnd(keyword));
            return;
        }
        _ = try parser.builder.addNode(.type_declaration, keyword, name + 1, name);

        const open = parser.findText(name + 1, "{") orelse return;
        const close = parser.matchingClose(open, "{", "}") orelse {
            try parser.builder.addDiagnostic(.expected_r_brace, parser.tokenEnd(open));
            return;
        };
        if (is_enum) {
            try parser.parseEnumVariants(open + 1, close);
        } else {
            try parser.parseFields(open + 1, close);
        }
    }

    fn parseNamedDeclaration(
        parser: *Parser,
        keyword: syntax.TokenIndex,
        tag: NodeTag,
    ) ParseError!void {
        const name = parser.nextCode(keyword + 1);
        if (parser.tokenTag(name) != .identifier) {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenEnd(keyword));
            return;
        }
        _ = try parser.builder.addNode(tag, keyword, name + 1, name);
        if (tag == .type_alias_declaration) {
            const equal = parser.findText(name + 1, "=") orelse return;
            const end = parser.findAnyText(equal + 1, &.{";"});
            try parser.addTypeReferences(equal + 1, end);
        }
    }

    fn parseValueDeclaration(
        parser: *Parser,
        keyword: syntax.TokenIndex,
        tag: NodeTag,
    ) ParseError!void {
        const end = parser.findAnyText(keyword + 1, &.{ ";", "=" });
        const name = parser.findBinding(keyword + 1, end) orelse {
            try parser.builder.addDiagnostic(.expected_identifier, parser.tokenEnd(keyword));
            return;
        };
        _ = try parser.builder.addNode(tag, keyword, name + 1, name);
        if (parser.findTextBefore(name + 1, end, ":")) |colon| {
            try parser.addTypeReferences(colon + 1, end);
        }
    }

    fn parseImpl(parser: *Parser, keyword: syntax.TokenIndex) ParseError!void {
        const end = parser.findAnyText(keyword + 1, &.{ "{", "where" });
        var index = keyword + 1;
        while (index < end) : (index += 1) {
            if (parser.tokenTag(index) != .identifier) continue;
            _ = try parser.builder.addNode(.impl_target, keyword, end, index);
            _ = try parser.builder.addNode(.type_reference, index, index + 1, index);
        }
    }

    fn parseFields(parser: *Parser, first: syntax.TokenIndex, last: syntax.TokenIndex) ParseError!void {
        var index = first;
        var depth: usize = 0;
        while (index < last) : (index += 1) {
            if (parser.tokenIsAny(index, &.{ "{", "(", "[" })) {
                depth += 1;
                continue;
            }
            if (parser.tokenIsAny(index, &.{ "}", ")", "]" })) {
                if (depth > 0) depth -= 1;
                continue;
            }
            if (depth != 0 or parser.tokenTag(index) != .identifier) continue;
            const colon = parser.nextCode(index + 1);
            if (!parser.tokenIs(colon, ":")) continue;
            const end = parser.findTypeBoundary(colon + 1, &.{ ",", "}" });
            _ = try parser.builder.addNode(.field_declaration, index, end, index);
            try parser.addTypeReferences(colon + 1, end);
        }
    }

    fn parseEnumVariants(parser: *Parser, first: syntax.TokenIndex, last: syntax.TokenIndex) ParseError!void {
        var index = first;
        var depth: usize = 0;
        var at_variant_start = true;
        while (index < last) : (index += 1) {
            if (parser.tokenIsAny(index, &.{ "(", "{", "[" })) {
                depth += 1;
                continue;
            }
            if (parser.tokenIsAny(index, &.{ ")", "}", "]" })) {
                if (depth > 0) depth -= 1;
                continue;
            }
            if (depth == 0 and parser.tokenIs(index, ",")) {
                at_variant_start = true;
            } else if (depth == 0 and at_variant_start and parser.tokenTag(index) == .identifier) {
                _ = try parser.builder.addNode(.enum_variant, index, index + 1, index);
                at_variant_start = false;
            }
        }
    }

    fn parseExpressions(parser: *Parser) ParseError!void {
        const eof = parser.eofIndex();
        var index: syntax.TokenIndex = 0;
        while (index < eof) : (index += 1) {
            if (parser.tokenTag(index) != .identifier) continue;
            const previous = parser.previousCode(index);
            const next = parser.nextCode(index + 1);
            if (previous != null and parser.tokenIs(previous.?, ".")) {
                _ = try parser.builder.addNode(.member_expression, previous.?, index + 1, index);
                if (parser.tokenIs(next, "(")) {
                    _ = try parser.builder.addNode(.call_expression, index, next + 1, index);
                }
            } else if (parser.tokenIs(next, "(") and !parser.isDeclarationName(index)) {
                _ = try parser.builder.addNode(.call_expression, index, next + 1, index);
            }
        }
    }

    fn addTypeReferences(parser: *Parser, first: syntax.TokenIndex, last: syntax.TokenIndex) ParseError!void {
        var index = first;
        while (index < last) : (index += 1) {
            if (parser.tokenTag(index) != .identifier) continue;
            _ = try parser.builder.addNode(.type_reference, index, index + 1, index);
        }
    }

    fn findBinding(
        parser: Parser,
        first: syntax.TokenIndex,
        last: syntax.TokenIndex,
    ) ?syntax.TokenIndex {
        var index = first;
        while (index < last) : (index += 1) {
            if (parser.tokenTag(index) == .identifier or
                (parser.tokenTag(index) == .keyword and std.mem.eql(u8, parser.tokenText(index), "self")))
            {
                return index;
            }
        }
        return null;
    }

    fn isDeclarationName(parser: Parser, token_index: syntax.TokenIndex) bool {
        const previous = parser.previousCode(token_index) orelse return false;
        if (parser.tokenTag(previous) != .keyword) return false;
        const text = parser.tokenText(previous);
        return std.mem.eql(u8, text, "fn") or
            std.mem.eql(u8, text, "struct") or
            std.mem.eql(u8, text, "enum") or
            std.mem.eql(u8, text, "union") or
            std.mem.eql(u8, text, "trait");
    }

    fn matchingClose(
        parser: Parser,
        open: syntax.TokenIndex,
        open_text: []const u8,
        close_text: []const u8,
    ) ?syntax.TokenIndex {
        var depth: usize = 0;
        var index = open;
        const eof = parser.eofIndex();
        while (index < eof) : (index += 1) {
            if (parser.tokenIs(index, open_text)) {
                depth += 1;
            } else if (parser.tokenIs(index, close_text)) {
                depth -= 1;
                if (depth == 0) return index;
            }
        }
        return null;
    }

    fn findText(parser: Parser, first: syntax.TokenIndex, text: []const u8) ?syntax.TokenIndex {
        const eof = parser.eofIndex();
        var index = first;
        while (index < eof) : (index += 1) {
            if (parser.tokenIs(index, text)) return index;
            if (parser.tokenIsAny(index, &.{ ";", "{" })) return null;
        }
        return null;
    }

    fn findTextBefore(
        parser: Parser,
        first: syntax.TokenIndex,
        last: syntax.TokenIndex,
        text: []const u8,
    ) ?syntax.TokenIndex {
        var index = first;
        while (index < last) : (index += 1) {
            if (parser.tokenIs(index, text)) return index;
        }
        return null;
    }

    fn findAnyText(
        parser: Parser,
        first: syntax.TokenIndex,
        texts: []const []const u8,
    ) syntax.TokenIndex {
        const eof = parser.eofIndex();
        var index = first;
        while (index < eof) : (index += 1) {
            if (parser.tokenIsAny(index, texts)) return index;
        }
        return eof;
    }

    fn findTypeBoundary(
        parser: Parser,
        first: syntax.TokenIndex,
        boundaries: []const []const u8,
    ) syntax.TokenIndex {
        const eof = parser.eofIndex();
        var nesting: Nesting = .{};
        var index = first;
        while (index < eof) : (index += 1) {
            if (nesting.isZero() and parser.tokenIsAny(index, boundaries)) return index;
            nesting.update(parser.tokenText(index));
        }
        return eof;
    }

    fn nextCode(parser: Parser, first: syntax.TokenIndex) syntax.TokenIndex {
        var index = first;
        const eof = parser.eofIndex();
        while (index < eof and parser.isTrivia(index)) index += 1;
        return index;
    }

    fn previousCode(parser: Parser, token_index: syntax.TokenIndex) ?syntax.TokenIndex {
        if (token_index == 0) return null;
        var index = token_index;
        while (index > 0) {
            index -= 1;
            if (!parser.isTrivia(index)) return index;
        }
        return null;
    }

    fn isTrivia(parser: Parser, token_index: syntax.TokenIndex) bool {
        return switch (parser.tokenTag(token_index)) {
            .comment, .documentation_comment, .attribute => true,
            else => false,
        };
    }

    fn tokenTag(parser: Parser, token_index: syntax.TokenIndex) TokenTag {
        return parser.builder.tokens.items[token_index].tag;
    }

    fn tokenText(parser: Parser, token_index: syntax.TokenIndex) []const u8 {
        return parser.builder.tokens.items[token_index].slice(parser.source);
    }

    fn tokenIs(parser: Parser, token_index: syntax.TokenIndex, text: []const u8) bool {
        return token_index < parser.builder.tokens.items.len and
            std.mem.eql(u8, parser.tokenText(token_index), text);
    }

    fn tokenIsAny(parser: Parser, token_index: syntax.TokenIndex, texts: []const []const u8) bool {
        if (token_index >= parser.builder.tokens.items.len) return false;
        for (texts) |text| if (parser.tokenIs(token_index, text)) return true;
        return false;
    }

    fn tokenEnd(parser: Parser, token_index: syntax.TokenIndex) usize {
        return parser.builder.tokens.items[token_index].end;
    }

    fn eofIndex(parser: Parser) syntax.TokenIndex {
        return @intCast(parser.builder.tokens.items.len - 1);
    }
};

const Nesting = struct {
    parens: usize = 0,
    brackets: usize = 0,
    braces: usize = 0,
    angles: usize = 0,

    fn isZero(nesting: Nesting) bool {
        return nesting.parens == 0 and nesting.brackets == 0 and
            nesting.braces == 0 and nesting.angles == 0;
    }

    fn update(nesting: *Nesting, text: []const u8) void {
        for (text) |byte| switch (byte) {
            '(' => nesting.parens += 1,
            ')' => if (nesting.parens > 0) {
                nesting.parens -= 1;
            },
            '[' => nesting.brackets += 1,
            ']' => if (nesting.brackets > 0) {
                nesting.brackets -= 1;
            },
            '{' => nesting.braces += 1,
            '}' => if (nesting.braces > 0) {
                nesting.braces -= 1;
            },
            '<' => nesting.angles += 1,
            '>' => if (nesting.angles > 0) {
                nesting.angles -= 1;
            },
            else => {},
        };
    }
};

const StringEnd = struct {
    end: usize,
    terminated: bool,
};

fn rawStringEnd(source: []const u8, marker_start: usize) ?StringEnd {
    var quote = marker_start;
    while (quote < source.len and source[quote] == '#') quote += 1;
    if (quote >= source.len or source[quote] != '"') return null;
    const hashes = quote - marker_start;
    var cursor = quote + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] != '"' or cursor + 1 + hashes > source.len) continue;
        var matches = true;
        for (source[cursor + 1 .. cursor + 1 + hashes]) |byte| {
            if (byte != '#') matches = false;
        }
        if (matches) return .{ .end = cursor + 1 + hashes, .terminated = true };
    }
    return .{ .end = source.len, .terminated = false };
}

fn cookedStringEnd(source: []const u8, start: usize) StringEnd {
    var cursor = start;
    while (cursor < source.len) {
        if (source[cursor] == '\\') {
            cursor = @min(cursor + 2, source.len);
            continue;
        }
        cursor += 1;
        if (source[cursor - 1] == '"') return .{ .end = cursor, .terminated = true };
    }
    return .{ .end = cursor, .terminated = false };
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

test "Rust parser records declarations bindings fields calls and types" {
    const source =
        \\pub struct Entry<'a> { value: &'a str }
        \\pub fn render(entry: &Entry<'_>) -> bool {
        \\    let count: usize = entry.value.len();
        \\    count > 0
        \\}
    ;
    var tree = try parse(std.testing.allocator, source);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .type_declaration, "Entry");
    try expectNodeMain(&tree, .field_declaration, "value");
    try expectNodeMain(&tree, .function_declaration, "render");
    try expectNodeMain(&tree, .parameter, "entry");
    try expectNodeMain(&tree, .type_reference, "Entry");
    try expectNodeMain(&tree, .variable_binding, "count");
    try expectNodeMain(&tree, .member_expression, "value");
    try expectNodeMain(&tree, .call_expression, "len");
    try tree.validate();
}

test "Rust parser preserves partial syntax and deterministic diagnostics" {
    const source = "fn broken(value: Entry { let text = r###\"unterminated";
    var first = try parse(std.testing.allocator, source);
    defer first.deinit(std.testing.allocator);
    var second = try parse(std.testing.allocator, source);
    defer second.deinit(std.testing.allocator);

    try expectNodeMain(&first, .function_declaration, "broken");
    try std.testing.expect(first.diagnostics.len >= 2);
    try first.validate();
    try std.testing.expectEqualSlices(Syntax.Token, first.tokens, second.tokens);
    try std.testing.expectEqualSlices(Syntax.Node, first.nodes, second.nodes);
    try std.testing.expectEqualSlices(Syntax.Diagnostic, first.diagnostics, second.diagnostics);
}

test "Rust parser keeps commas inside nested generic parameter types" {
    const source = "fn collect(values: Result<Vec<u8>, Error>, limit: usize) {}";
    var tree = try parse(std.testing.allocator, source);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .parameter, "values");
    try expectNodeMain(&tree, .parameter, "limit");
    try expectNodeMain(&tree, .type_reference, "Result");
    try expectNodeMain(&tree, .type_reference, "Vec");
    try expectNodeMain(&tree, .type_reference, "Error");
    try tree.validate();
}

fn expectNodeMain(tree: *const Tree, tag: NodeTag, expected: []const u8) !void {
    for (tree.nodes) |node| {
        if (node.tag == tag and std.mem.eql(u8, tree.tokenSlice(node.main_token), expected)) return;
    }
    return error.TestExpectedEqual;
}
