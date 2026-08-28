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
    var parser: Parser = .{ .source = source, .sink = sink, .dialect = dialect };
    try generic.highlight(source, sink, .{
        .line_comments = if (dialect == .fsharp) &.{"//"} else &.{},
        .block_comments = &.{.{ .open = "(*", .close = "*)" }},
        .nested_block_comments = true,
        .keywords = keywords(dialect),
        .types = types(dialect),
        .classify_identifiers = false,
        .identifier_dash = false,
        .triple_quoted_strings = dialect == .fsharp,
        .preprocessor = dialect == .fsharp,
        .structural_observer = .{
            .context = &parser,
            .before = Parser.before,
            .observe = Parser.observe,
        },
    });
}

const Expected = enum { namespace, type, declaration };

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    dialect: Dialect,
    line_start: usize = 0,
    expected: ?Expected = null,
    parameter_mode: bool = false,
    type_context: bool = false,
    constructor_pending: bool = false,
    brace_depth: usize = 0,

    fn before(context: *anyopaque, index: *usize) api.HighlightError!bool {
        const parser: *Parser = @ptrCast(@alignCast(context));
        return try parser.scanAttribute(index) or parser.scanTypeVariable(index) or try parser.scanLabel(index);
    }

    fn observe(context: *anyopaque, index: *usize, event: generic.StructuralEvent) api.HighlightError!void {
        const parser: *Parser = @ptrCast(@alignCast(context));
        switch (event) {
            .word => |word| try parser.scanWord(index, word.start, word.end, word.lexical_scope),
            .operator => |operator| parser.observeOperator(parser.source[operator.start..operator.end]),
            .punctuation => |byte| parser.observePunctuation(byte),
            .newline => {
                parser.line_start = index.*;
                parser.resetLineState();
            },
        }
    }

    fn scanWord(parser: *Parser, index: *usize, start: usize, end: usize, lexical_scope: ?Scope) api.HighlightError!void {
        const word = parser.source[start..end];

        if (lexical_scope == .keyword) {
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
        if (lexical_scope == .type or lexical_scope == .boolean or lexical_scope == .constant or
            wordIs(word, &.{ "Some", "Ok", "Error" })) return;

        if (parser.expected) |expected| switch (expected) {
            .namespace => {
                index.* = scanner.qualifiedIdentifierEnd(parser.source, start, ".", .apostrophe, .identifier);
                try parser.sink.add(start, index.*, .namespace);
                var separator = start;
                while (std.mem.indexOfScalarPos(u8, parser.source, separator, '.')) |dot| {
                    if (dot >= index.*) break;
                    try parser.sink.add(dot, dot + 1, .punctuation);
                    separator = dot + 1;
                }
                parser.expected = null;
                return;
            },
            .type => {
                try parser.sink.add(start, end, .type);
                parser.expected = null;
                return;
            },
            .declaration => {
                if (scanner.nextNonSpace(parser.source, end) == '.') {
                    try parser.sink.add(start, end, .parameter);
                } else {
                    try parser.sink.add(start, end, .function);
                    parser.expected = null;
                    parser.parameter_mode = true;
                }
                return;
            },
        };

        const next = scanner.nextNonSpace(parser.source, end);
        if (next == ':' and (parser.brace_depth > 0 or
            (parser.dialect == .fsharp and !parser.parameter_mode)))
        {
            try parser.sink.add(start, end, .property);
        } else if (parser.constructor_pending and std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, end, .constructor);
            parser.constructor_pending = false;
        } else if (parser.type_context) {
            try parser.sink.add(start, end, .type);
        } else if (parser.parameter_mode) {
            try parser.sink.add(start, end, .parameter);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, end, if (next == '(') .function else .property);
        } else if (next == '(') {
            try parser.sink.add(start, end, .function);
        } else if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, end, .constructor);
        } else {
            try parser.sink.add(start, end, .variable);
        }
    }

    fn scanAttribute(parser: *Parser, index: *usize) api.HighlightError!bool {
        const start = index.*;
        const fsharp = parser.dialect == .fsharp and std.mem.startsWith(u8, parser.source[start..], "[<");
        const ocaml = parser.dialect == .ocaml and std.mem.startsWith(u8, parser.source[start..], "[@");
        if (!fsharp and !ocaml) return false;
        const closing = if (fsharp) ">]" else "]";
        const close = std.mem.indexOfPos(u8, parser.source, start + 2, closing);
        index.* = if (close) |at| at + closing.len else parser.source.len;
        try parser.sink.add(start, index.*, .attribute);
        return true;
    }

    fn scanTypeVariable(parser: *Parser, index: *usize) bool {
        const start = index.*;
        if (start >= parser.source.len or parser.source[start] != '\'') return false;
        if (start + 1 >= parser.source.len or !scanner.isAsciiIdentifierStart(parser.source[start + 1])) return false;
        const end = scanner.identifierEnd(parser.source, start + 1, .ascii);
        if (end < parser.source.len and parser.source[end] == '\'') return false;
        parser.sink.add(start, end, .type) catch return false;
        index.* = end;
        return true;
    }

    fn scanLabel(parser: *Parser, index: *usize) api.HighlightError!bool {
        const start = index.*;
        if (start >= parser.source.len or (parser.source[start] != '~' and parser.source[start] != '?')) return false;
        if (start + 1 >= parser.source.len or !scanner.isAsciiIdentifierStart(parser.source[start + 1])) return false;
        index.* = scanner.identifierEnd(parser.source, start + 1, .ascii);
        try parser.sink.add(start, index.*, .parameter);
        return true;
    }

    fn observeOperator(parser: *Parser, operator: []const u8) void {
        if (operator[0] == ':') {
            parser.type_context = true;
            parser.parameter_mode = false;
        } else if (operator[0] == '=') {
            parser.expected = null;
            parser.parameter_mode = false;
            parser.type_context = false;
        } else if (std.mem.eql(u8, operator, "->")) {
            parser.parameter_mode = false;
            parser.type_context = false;
        } else if (operator[0] == '|' and !std.mem.eql(u8, operator, "|>")) {
            parser.constructor_pending = true;
            parser.parameter_mode = false;
        }
    }

    fn observePunctuation(parser: *Parser, byte: u8) void {
        switch (byte) {
            '{' => parser.brace_depth += 1,
            '}' => parser.brace_depth -|= 1,
            ')', ']' => parser.type_context = false,
            ';' => parser.resetLineState(),
            else => {},
        }
    }

    fn resetLineState(parser: *Parser) void {
        parser.expected = null;
        parser.parameter_mode = false;
        parser.type_context = false;
        parser.constructor_pending = false;
    }
};

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
