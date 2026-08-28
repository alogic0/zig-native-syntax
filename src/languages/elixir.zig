const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "elixir",
    .display_name = "Elixir",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const keywords = &.{ "after", "alias", "and", "case", "catch", "cond", "def", "defcallback", "defdelegate", "defexception", "defguard", "defguardp", "defimpl", "defmacro", "defmacrop", "defmodule", "defoverridable", "defp", "defprotocol", "defstruct", "do", "else", "end", "fn", "for", "if", "import", "in", "not", "or", "quote", "raise", "receive", "require", "rescue", "super", "throw", "try", "type", "unless", "unquote", "use", "when", "with" };
const types = &.{ "atom", "binary", "bitstring", "boolean", "float", "fun", "integer", "iodata", "list", "map", "module", "non_neg_integer", "number", "pid", "port", "reference", "term", "tuple" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .keywords = keywords,
        .types = types,
        .constants = &.{"nil"},
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
    anonymous_parameters: bool = false,
    expected: ?Scope = null,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            '~' => if (!try parser.scanSigil()) {
                parser.index += 1;
            },
            ':' => try parser.scanAtom(),
            '@' => parser.skipAttribute(),
            '%' => {
                parser.index += 1;
                if (parser.index < parser.source.len and std.ascii.isUpper(parser.source[parser.index])) {
                    const end = aliasEnd(parser.source, parser.index);
                    try parser.sink.add(parser.index, end, .type);
                    parser.index = end;
                }
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
            '-' => {
                if (std.mem.startsWith(u8, parser.source[parser.index..], "->")) {
                    parser.anonymous_parameters = false;
                    parser.index += 2;
                } else parser.index += 1;
            },
            '\n', ';' => {
                parser.expected = null;
                parser.anonymous_parameters = false;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .callable);
        var word = parser.source[start..parser.index];

        if (parser.expected) |scope| {
            if (scope == .namespace) parser.index = aliasEnd(parser.source, start);
            word = parser.source[start..parser.index];
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            if (scope == .function) parser.awaiting_parameters = true;
            return;
        }
        if (wordIs(word, &.{ "defmodule", "defprotocol", "defimpl" })) {
            parser.expected = .namespace;
            return;
        }
        if (wordIs(word, &.{ "def", "defp", "defmacro", "defmacrop", "defguard", "defguardp", "defdelegate", "defcallback" })) {
            parser.expected = .function;
            return;
        }
        if (std.mem.eql(u8, word, "fn")) {
            parser.anonymous_parameters = true;
            return;
        }
        if (isKeyword(word)) {
            if (isKeywordKey(parser.source, parser.index)) try parser.sink.add(start, parser.index, .property);
            return;
        }
        if (isType(word) or isLiteral(word)) return;

        if (std.ascii.isUpper(word[0])) {
            parser.index = aliasEnd(parser.source, start);
            try parser.sink.add(start, parser.index, .type);
        } else if (parser.anonymous_parameters or
            (parser.parameter_depth != null and isParameterPosition(parser.source, start)))
        {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (isKeywordKey(parser.source, parser.index)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, if (scanner.nextNonSpace(parser.source, parser.index) == '(') .function else .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (wordIs(word, &.{ "__MODULE__", "__ENV__", "self" })) {
            try parser.sink.add(start, parser.index, .builtin);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanAtom(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        if (parser.index + 1 >= parser.source.len or parser.source[parser.index + 1] == ':') {
            parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
            return;
        }
        parser.index += 1;
        if (parser.source[parser.index] == '\'' or parser.source[parser.index] == '"') {
            parser.skipString(parser.source[parser.index]);
        } else if (scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .callable);
        }
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .constant);
    }

    fn skipAttribute(parser: *Parser) void {
        parser.index += 1;
        if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .callable);
        }
    }

    fn scanSigil(parser: *Parser) api.HighlightError!bool {
        const start = parser.index;
        if (start + 2 >= parser.source.len or !std.ascii.isAlphabetic(parser.source[start + 1])) return false;
        const opening = parser.source[start + 2];
        if (std.mem.indexOfScalar(u8, "([{</|'\"", opening) == null) return false;
        const closing = scanner.matchingDelimiter(opening);
        const heredoc = (opening == '\'' or opening == '"') and start + 4 < parser.source.len and
            parser.source[start + 3] == opening and parser.source[start + 4] == opening;
        if (heredoc) {
            parser.index = scanner.stringEnd(parser.source, start + 2, opening, true);
        } else {
            parser.index = start + 3;
            var depth: usize = 1;
            while (parser.index < parser.source.len) {
                if (parser.source[parser.index] == '\\') {
                    parser.index = scanner.escapeEnd(parser.source, parser.index);
                } else if (opening != closing and parser.source[parser.index] == opening) {
                    depth += 1;
                    parser.index += 1;
                } else if (parser.source[parser.index] == closing) {
                    depth -= 1;
                    parser.index += 1;
                    if (depth == 0) break;
                } else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
            }
        }
        while (parser.index < parser.source.len and std.ascii.isAlphabetic(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, start + 2, .special);
        try parser.sink.add(start, parser.index, .string);
        return true;
    }

    fn skipString(parser: *Parser, quote: u8) void {
        parser.index = scanner.stringEnd(parser.source, parser.index, quote, true);
    }
};

fn aliasEnd(source: []const u8, start: usize) usize {
    return scanner.qualifiedIdentifierEnd(source, start, ".", .callable, .uppercase);
}

fn isParameterPosition(source: []const u8, start: usize) bool {
    const previous = scanner.previousNonSpace(source, start) orelse return false;
    return previous == '(' or previous == ',';
}

fn isKeywordKey(source: []const u8, after: usize) bool {
    var index = after;
    while (index < source.len and std.ascii.isWhitespace(source[index]) and source[index] != '\n') index += 1;
    return index < source.len and source[index] == ':' and
        (index + 1 >= source.len or source[index + 1] != ':');
}

const wordIs = scanner.wordIs;

fn isKeyword(word: []const u8) bool {
    return wordIs(word, keywords);
}

fn isType(word: []const u8) bool {
    return wordIs(word, types);
}

fn isLiteral(word: []const u8) bool {
    return wordIs(word, &.{ "true", "false", "nil" });
}
