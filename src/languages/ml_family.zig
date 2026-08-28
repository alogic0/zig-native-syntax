const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const Dialect = enum { fsharp, ocaml };

const fsharp_keywords = &.{ "abstract", "and", "as", "base", "class", "default", "do", "else", "exception", "for", "fun", "function", "if", "in", "inherit", "inline", "interface", "internal", "let", "match", "member", "module", "mutable", "namespace", "new", "of", "open", "override", "private", "public", "rec", "return", "static", "then", "try", "type", "val", "while", "with", "yield" };
const fsharp_types = &.{ "bool", "byte", "char", "decimal", "float", "float32", "int", "int16", "int64", "list", "obj", "option", "string", "uint", "uint16", "uint64", "unit" };
const ocaml_keywords = &.{ "and", "as", "assert", "begin", "class", "constraint", "do", "done", "downto", "else", "end", "exception", "external", "for", "fun", "function", "functor", "if", "in", "include", "inherit", "initializer", "lazy", "let", "match", "method", "module", "mutable", "new", "nonrec", "object", "of", "open", "private", "rec", "sig", "struct", "then", "to", "try", "type", "val", "virtual", "when", "while", "with" };
const ocaml_types = &.{ "array", "bool", "bytes", "char", "float", "int", "int32", "int64", "list", "option", "result", "string", "unit" };

pub fn highlight(source: []const u8, sink: *api.CaptureSink, dialect: Dialect) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = if (dialect == .fsharp) &.{"//"} else &.{},
        .block_comments = &.{.{ .open = "(*", .close = "*)" }},
        .nested_block_comments = true,
        .keywords = keywords(dialect),
        .types = types(dialect),
        .classify_identifiers = false,
        .identifier_dash = false,
        .triple_quoted_strings = dialect == .fsharp,
    });
    var parser: Parser = .{ .source = source, .sink = sink, .dialect = dialect };
    try parser.run();
}

const Expected = enum { namespace, type, declaration };

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    dialect: Dialect,
    index: usize = 0,
    line_start: usize = 0,
    expected: ?Expected = null,
    parameter_mode: bool = false,
    type_context: bool = false,
    constructor_pending: bool = false,
    brace_depth: usize = 0,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "(*")) {
                parser.index = nestedCommentEnd(parser.source, parser.index);
                continue;
            }
            if (parser.dialect == .fsharp and std.mem.startsWith(u8, parser.source[parser.index..], "//")) {
                parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                continue;
            }
            if (try parser.scanAttribute()) continue;

            switch (parser.source[parser.index]) {
                '"' => parser.index = scanner.stringEnd(parser.source, parser.index, '"', parser.dialect == .fsharp),
                '\'' => {
                    if (!parser.scanTypeVariable()) {
                        parser.index = scanner.quotedEnd(parser.source, parser.index, '\'', true);
                    }
                },
                '#' => {
                    if (parser.dialect == .fsharp and parser.onlyIndentBefore(parser.index)) {
                        const start = parser.index;
                        parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                        try parser.sink.add(start, parser.index, .macro);
                    } else parser.index += 1;
                },
                ':' => {
                    parser.type_context = true;
                    parser.parameter_mode = false;
                    parser.index += 1;
                },
                '=' => {
                    parser.expected = null;
                    parser.parameter_mode = false;
                    parser.type_context = false;
                    parser.index += 1;
                },
                '-' => {
                    if (std.mem.startsWith(u8, parser.source[parser.index..], "->")) {
                        parser.parameter_mode = false;
                        parser.type_context = false;
                        parser.index += 2;
                    } else parser.index += 1;
                },
                '|' => {
                    parser.constructor_pending = true;
                    parser.parameter_mode = false;
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
                ')', ']' => {
                    parser.type_context = false;
                    parser.index += 1;
                },
                '\n', ';' => {
                    parser.index += 1;
                    if (parser.source[parser.index - 1] == '\n') parser.line_start = parser.index;
                    parser.expected = null;
                    parser.parameter_mode = false;
                    parser.type_context = false;
                    parser.constructor_pending = false;
                },
                '~', '?' => {
                    if (!try parser.scanLabel()) parser.index += 1;
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, start, .apostrophe);
        const word = parser.source[start..parser.index];

        if (isKeyword(parser.dialect, word)) {
            if (parser.expected == .declaration and wordIs(word, declarationModifiers(parser.dialect))) return;
            if (wordIs(word, &.{ "module", "namespace", "open", "include" })) {
                parser.expected = .namespace;
            } else if (wordIs(word, &.{ "type", "class", "interface", "exception" })) {
                parser.expected = .type;
            } else if (wordIs(word, declarationKeywords(parser.dialect))) {
                parser.expected = .declaration;
            } else if (wordIs(word, &.{ "fun", "function" })) {
                parser.parameter_mode = true;
            } else if (std.mem.eql(u8, word, "of")) {
                parser.type_context = true;
            }
            return;
        }
        if (isType(parser.dialect, word) or isLiteral(word)) return;

        if (parser.expected) |expected| switch (expected) {
            .namespace => {
                parser.index = scanner.qualifiedIdentifierEnd(parser.source, start, ".", .apostrophe, .identifier);
                try parser.sink.add(start, parser.index, .namespace);
                parser.expected = null;
                return;
            },
            .type => {
                try parser.sink.add(start, parser.index, .type);
                parser.expected = null;
                return;
            },
            .declaration => {
                if (scanner.nextNonSpace(parser.source, parser.index) == '.') {
                    try parser.sink.add(start, parser.index, .parameter);
                } else {
                    try parser.sink.add(start, parser.index, .function);
                    parser.expected = null;
                    parser.parameter_mode = true;
                }
                return;
            },
        };

        const next = scanner.nextNonSpace(parser.source, parser.index);
        if (parser.brace_depth > 0 and next == ':') {
            try parser.sink.add(start, parser.index, .property);
        } else if (parser.constructor_pending and std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .constructor);
            parser.constructor_pending = false;
        } else if (parser.type_context) {
            try parser.sink.add(start, parser.index, .type);
        } else if (parser.parameter_mode) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, if (next == '(') .function else .property);
        } else if (next == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .constructor);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanAttribute(parser: *Parser) api.HighlightError!bool {
        const start = parser.index;
        const fsharp = parser.dialect == .fsharp and std.mem.startsWith(u8, parser.source[start..], "[<");
        const ocaml = parser.dialect == .ocaml and std.mem.startsWith(u8, parser.source[start..], "[@");
        if (!fsharp and !ocaml) return false;
        const closing = if (fsharp) ">]" else "]";
        const close = std.mem.indexOfPos(u8, parser.source, start + 2, closing);
        parser.index = if (close) |at| at + closing.len else parser.source.len;
        try parser.sink.add(start, parser.index, .attribute);
        return true;
    }

    fn scanTypeVariable(parser: *Parser) bool {
        const start = parser.index;
        if (start + 1 >= parser.source.len or !scanner.isAsciiIdentifierStart(parser.source[start + 1])) return false;
        const end = scanner.identifierEnd(parser.source, start + 1, .ascii);
        if (end < parser.source.len and parser.source[end] == '\'') return false;
        parser.sink.add(start, end, .type) catch return false;
        parser.index = end;
        return true;
    }

    fn scanLabel(parser: *Parser) api.HighlightError!bool {
        const start = parser.index;
        if (start + 1 >= parser.source.len or !scanner.isAsciiIdentifierStart(parser.source[start + 1])) return false;
        parser.index = scanner.identifierEnd(parser.source, start + 1, .ascii);
        try parser.sink.add(start, parser.index, .parameter);
        return true;
    }

    fn onlyIndentBefore(parser: Parser, position: usize) bool {
        return scanner.onlyIndentBefore(parser.source, parser.line_start, position);
    }
};

fn nestedCommentEnd(source: []const u8, start: usize) usize {
    var index = start + 2;
    var depth: usize = 1;
    while (index < source.len and depth > 0) {
        if (std.mem.startsWith(u8, source[index..], "(*")) {
            depth += 1;
            index += 2;
        } else if (std.mem.startsWith(u8, source[index..], "*)")) {
            depth -= 1;
            index += 2;
        } else {
            index += scanner.validUtf8Length(source[index..]);
        }
    }
    return index;
}

fn keywords(dialect: Dialect) []const []const u8 {
    return if (dialect == .fsharp) fsharp_keywords else ocaml_keywords;
}

fn types(dialect: Dialect) []const []const u8 {
    return if (dialect == .fsharp) fsharp_types else ocaml_types;
}

fn declarationKeywords(dialect: Dialect) []const []const u8 {
    return if (dialect == .fsharp) &.{ "let", "and", "member", "override", "val" } else &.{ "let", "and", "method", "val", "external" };
}

fn declarationModifiers(dialect: Dialect) []const []const u8 {
    return if (dialect == .fsharp) &.{ "rec", "inline", "private", "internal", "public", "static", "mutable" } else &.{ "rec", "nonrec", "private", "virtual", "mutable" };
}

const wordIs = scanner.wordIs;

fn isKeyword(dialect: Dialect, word: []const u8) bool {
    return wordIs(word, keywords(dialect));
}

fn isType(dialect: Dialect, word: []const u8) bool {
    return wordIs(word, types(dialect));
}

fn isLiteral(word: []const u8) bool {
    return wordIs(word, &.{ "true", "false", "None", "Some", "Ok", "Error", "null" });
}

test "ML family scanner preserves nested comments" {
    const source = "let run x = (* outer (* nested *) still comment *) x";
    try std.testing.expectEqual(source.len - 2, nestedCommentEnd(source, 12));
}
