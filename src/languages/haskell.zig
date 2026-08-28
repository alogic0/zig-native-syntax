const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "haskell",
    .display_name = "Haskell",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const keywords = &.{ "as", "case", "class", "data", "default", "deriving", "do", "else", "family", "foreign", "hiding", "if", "import", "in", "infix", "infixl", "infixr", "instance", "let", "module", "newtype", "of", "qualified", "then", "type", "where" };
const types = &.{ "Bool", "Char", "Double", "Either", "Float", "IO", "Int", "Integer", "Maybe", "Ordering", "String", "Text", "Word" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = &.{"--"},
        .block_comments = &.{.{ .open = "{-", .close = "-}" }},
        .keywords = keywords,
        .types = types,
        .constants = &.{"Nothing"},
        .booleans = &.{ "True", "False" },
        .classify_identifiers = false,
        .identifier_dash = false,
    });
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    line_start: usize = 0,
    expected: ?Scope = null,
    type_signature: bool = false,
    equation_parameters: bool = false,
    data_declaration: bool = false,
    brace_depth: usize = 0,
    inline_binding_pending: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "{-#")) {
                try parser.scanPragma();
                continue;
            }
            if (std.mem.startsWith(u8, parser.source[parser.index..], "{-")) {
                parser.skipNestedComment();
                continue;
            }
            if (std.mem.startsWith(u8, parser.source[parser.index..], "--")) {
                parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                continue;
            }
            switch (parser.source[parser.index]) {
                '"', '\'' => parser.index = scanner.quotedEnd(parser.source, parser.index, parser.source[parser.index], true),
                ':' => {
                    if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == ':') {
                        parser.type_signature = true;
                        parser.equation_parameters = false;
                        parser.index += 2;
                    } else parser.index += 1;
                },
                '=' => {
                    parser.equation_parameters = false;
                    parser.type_signature = false;
                    parser.index += 1;
                },
                '{' => {
                    parser.brace_depth += 1;
                    parser.index += 1;
                },
                '}' => {
                    parser.brace_depth -|= 1;
                    parser.index += 1;
                },
                '\n' => {
                    parser.index += 1;
                    parser.line_start = parser.index;
                    parser.expected = null;
                    parser.type_signature = false;
                    parser.equation_parameters = false;
                    parser.data_declaration = false;
                    parser.inline_binding_pending = false;
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .apostrophe);
        const word = parser.source[start..parser.index];
        const first_on_line = parser.onlyIndentBefore(start);

        if (parser.expected) |scope| {
            if (scope == .namespace and std.mem.eql(u8, word, "qualified")) return;
            if (scope == .namespace) parser.index = qualifiedEnd(parser.source, start);
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            return;
        }
        if (std.mem.eql(u8, word, "module")) {
            parser.expected = .namespace;
            return;
        }
        if (std.mem.eql(u8, word, "import")) {
            parser.expected = .namespace;
            return;
        }
        if (wordIs(word, &.{ "data", "newtype", "type", "class", "family" })) {
            parser.expected = .type;
            parser.data_declaration = wordIs(word, &.{ "data", "newtype" });
            return;
        }
        if (isKeyword(word) or isLiteral(word)) {
            parser.inline_binding_pending = std.mem.eql(u8, word, "let");
            return;
        }

        if (first_on_line or parser.inline_binding_pending) {
            const declaration = lineDeclaration(parser.source, parser.index);
            if (declaration != .none) {
                try parser.sink.add(start, parser.index, .function);
                parser.equation_parameters = declaration == .equation;
                parser.inline_binding_pending = false;
                return;
            }
        }
        parser.inline_binding_pending = false;
        if (parser.type_signature) {
            try parser.sink.add(start, parser.index, .type);
        } else if (parser.equation_parameters and std.ascii.isLower(word[0])) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (parser.brace_depth > 0 and nextIsTypeSignature(parser.source, parser.index)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (std.ascii.isUpper(word[0])) {
            parser.index = qualifiedEnd(parser.source, start);
            try parser.sink.add(start, parser.index, if (isType(word) and !parser.data_declaration) .type else .constructor);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanPragma(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        const close = std.mem.indexOfPos(u8, parser.source, start + 3, "#-}");
        parser.index = if (close) |at| at + 3 else parser.source.len;
        try parser.sink.add(start, parser.index, .attribute);
    }

    fn skipNestedComment(parser: *Parser) void {
        parser.index += 2;
        var depth: usize = 1;
        while (parser.index < parser.source.len and depth > 0) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "{-")) {
                depth += 1;
                parser.index += 2;
            } else if (std.mem.startsWith(u8, parser.source[parser.index..], "-}")) {
                depth -= 1;
                parser.index += 2;
            } else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
    }

    fn onlyIndentBefore(parser: Parser, position: usize) bool {
        return scanner.onlyIndentBefore(parser.source, parser.line_start, position);
    }
};

const Declaration = enum { none, signature, equation };

fn lineDeclaration(source: []const u8, after: usize) Declaration {
    const end = scanner.lineEnd(source, after, source.len);
    const tail = source[after..end];
    if (std.mem.indexOf(u8, tail, "::") != null) return .signature;
    if (std.mem.indexOfScalar(u8, tail, '=') != null) return .equation;
    return .none;
}

fn nextIsTypeSignature(source: []const u8, after: usize) bool {
    var index = after;
    while (index < source.len and (source[index] == ' ' or source[index] == '\t')) index += 1;
    return index + 1 < source.len and source[index] == ':' and source[index + 1] == ':';
}

fn qualifiedEnd(source: []const u8, start: usize) usize {
    return scanner.qualifiedIdentifierEnd(source, start, ".", .apostrophe, .identifier);
}

const wordIs = scanner.wordIs;

fn isKeyword(word: []const u8) bool {
    return wordIs(word, keywords);
}

fn isType(word: []const u8) bool {
    return wordIs(word, types);
}

fn isLiteral(word: []const u8) bool {
    return wordIs(word, &.{ "True", "False", "Nothing" });
}
