const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "julia",
    .display_name = "Julia",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const keywords = &.{ "abstract", "baremodule", "begin", "break", "catch", "const", "continue", "do", "else", "elseif", "end", "export", "finally", "for", "function", "global", "if", "import", "in", "let", "local", "macro", "module", "mutable", "primitive", "quote", "return", "struct", "try", "using", "where", "while" };
const types = &.{ "Any", "Bool", "Char", "Complex", "Float16", "Float32", "Float64", "Function", "Int", "Int8", "Int16", "Int32", "Int64", "Integer", "Nothing", "Number", "Real", "String", "UInt", "UInt8", "UInt16", "UInt32", "UInt64", "Union", "Vector" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .block_comments = &.{.{ .open = "#=", .close = "=#" }},
        .keywords = keywords,
        .types = types,
        .constants = &.{ "missing", "nothing" },
        .classify_identifiers = false,
        .identifier_dash = false,
        .triple_quoted_strings = true,
    });
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    awaiting_parameters: bool = false,
    expected: ?Scope = null,
    expect_type: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "#=")) {
                parser.index = scanner.blockCommentEnd(parser.source, parser.index, parser.source.len);
                continue;
            }
            switch (parser.source[parser.index]) {
                '#' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
                '\'', '"', '`' => parser.skipString(parser.source[parser.index]),
                '@' => try parser.scanMacro(),
                ':' => {
                    if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == ':') {
                        parser.expect_type = true;
                        parser.index += 2;
                    } else try parser.scanSymbol();
                },
                '<' => {
                    if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == ':') {
                        parser.expect_type = true;
                        parser.index += 2;
                    } else parser.index += 1;
                },
                '(' => {
                    parser.paren_depth += 1;
                    if (parser.awaiting_parameters) {
                        parser.parameter_depth = parser.paren_depth;
                        parser.awaiting_parameters = false;
                    }
                    parser.index += 1;
                },
                ')' => {
                    if (parser.parameter_depth == parser.paren_depth) parser.parameter_depth = null;
                    parser.paren_depth -|= 1;
                    parser.index += 1;
                },
                '\n', ';' => {
                    parser.expected = null;
                    parser.expect_type = false;
                    parser.index += 1;
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .callable);
        const word = parser.source[start..parser.index];

        if (parser.expected) |scope| {
            if (scope == .namespace) parser.index = qualifiedEnd(parser.source, start);
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            if (scope == .function) parser.awaiting_parameters = true;
            return;
        }
        if (wordIs(word, &.{ "module", "baremodule" })) {
            parser.expected = .namespace;
            return;
        }
        if (wordIs(word, &.{ "struct", "abstract", "primitive" })) {
            parser.expected = .type;
            return;
        }
        if (std.mem.eql(u8, word, "function")) {
            parser.expected = .function;
            return;
        }
        if (std.mem.eql(u8, word, "macro")) {
            parser.expected = .macro;
            return;
        }
        if (std.mem.eql(u8, word, "where")) {
            parser.expect_type = true;
            return;
        }
        if (isKeyword(word) or isLiteral(word)) return;

        if (parser.expect_type or std.ascii.isUpper(word[0]) or isType(word)) {
            parser.index = qualifiedEnd(parser.source, start);
            try parser.sink.add(start, parser.index, .type);
            parser.expect_type = false;
        } else if (parser.parameter_depth != null and isParameterPosition(parser.source, start)) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, if (scanner.nextNonSpace(parser.source, parser.index) == '(') .function else .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
            if (looksLikeShortDeclaration(parser.source, parser.index)) parser.awaiting_parameters = true;
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanMacro(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .callable);
            try parser.sink.add(start, parser.index, .macro);
        }
    }

    fn scanSymbol(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .callable);
            try parser.sink.add(start, parser.index, .constant);
        }
    }

    fn skipString(parser: *Parser, quote: u8) void {
        parser.index = scanner.stringEnd(parser.source, parser.index, quote, quote == '"');
    }
};

fn looksLikeShortDeclaration(source: []const u8, open: usize) bool {
    var index = open;
    var depth: usize = 0;
    while (index < source.len) : (index += 1) switch (source[index]) {
        '(' => depth += 1,
        ')' => {
            depth -|= 1;
            if (depth == 0) {
                return scanner.nextNonSpace(source, index + 1) == '=';
            }
        },
        '\n' => return false,
        else => {},
    };
    return false;
}

fn qualifiedEnd(source: []const u8, start: usize) usize {
    return scanner.qualifiedIdentifierEnd(source, start, ".", .callable, .identifier);
}

fn isParameterPosition(source: []const u8, start: usize) bool {
    const previous = scanner.previousNonSpace(source, start) orelse return false;
    return previous == '(' or previous == ',' or previous == ';';
}

const wordIs = scanner.wordIs;

fn isKeyword(word: []const u8) bool {
    return wordIs(word, keywords);
}

fn isType(word: []const u8) bool {
    return wordIs(word, types);
}

fn isLiteral(word: []const u8) bool {
    return wordIs(word, &.{ "true", "false", "missing", "nothing" });
}
