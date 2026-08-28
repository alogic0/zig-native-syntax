const std = @import("std");
const api = @import("../backend.zig");
const Capture = @import("../capture.zig").Capture;
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
        .classify_identifiers = true,
        .identifier_dash = false,
        .triple_quoted_strings = dialect == .fsharp,
        .preprocessor = dialect == .fsharp,
        .apostrophe_identifiers = true,
    });
    var parser: Parser = .{
        .source = source,
        .sink = sink,
        .dialect = dialect,
        .capture_count = sink.captures().len,
    };
    try parser.run();
}

const Expected = enum { namespace, type, declaration };

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    dialect: Dialect,
    capture_count: usize,
    source_cursor: usize = 0,
    expected: ?Expected = null,
    parameter_mode: bool = false,
    type_context: bool = false,
    constructor_pending: bool = false,
    brace_depth: usize = 0,
    suppressed_until: usize = 0,
    namespace_until: usize = 0,

    fn run(parser: *Parser) api.HighlightError!void {
        var capture_index: usize = 0;
        while (capture_index < parser.capture_count) : (capture_index += 1) {
            const capture = parser.sink.captures()[capture_index];
            if (capture.span.start >= parser.source_cursor) {
                if (std.mem.indexOfScalar(u8, parser.source[parser.source_cursor..capture.span.start], '\n') != null) {
                    parser.resetLineState();
                }
                parser.source_cursor = capture.span.end;
            } else {
                parser.source_cursor = @max(parser.source_cursor, capture.span.end);
            }

            if (capture.span.start < parser.suppressed_until) {
                parser.empty(capture_index);
                continue;
            }
            if (capture.span.start < parser.namespace_until and isIdentifierScope(capture.scope)) {
                parser.setScope(capture_index, .namespace);
                continue;
            }

            switch (capture.scope) {
                .keyword => parser.observeKeyword(capture),
                .type, .builtin, .boolean, .constant => {},
                .variable, .property, .function, .label => try parser.refineWord(capture_index, capture),
                .operator => try parser.refineOperator(capture_index, capture),
                .punctuation => try parser.refinePunctuation(capture_index, capture),
                else => {},
            }
        }
    }

    fn observeKeyword(parser: *Parser, capture: Capture) void {
        const word = parser.source[capture.span.start..capture.span.end];
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
    }

    fn refineWord(parser: *Parser, capture_index: usize, capture: Capture) api.HighlightError!void {
        const start = capture.span.start;
        const end = capture.span.end;
        const word = parser.source[start..end];

        if (wordIs(word, &.{ "Some", "Ok", "Error" })) {
            parser.empty(capture_index);
            return;
        }

        if (parser.expected) |expected| switch (expected) {
            .namespace => {
                const namespace_end = scanner.qualifiedIdentifierEnd(parser.source, start, ".", .apostrophe, .identifier);
                parser.setScope(capture_index, .namespace);
                parser.namespace_until = namespace_end;
                try parser.sink.add(start, namespace_end, .namespace);
                parser.expected = null;
                return;
            },
            .type => {
                parser.setScope(capture_index, .type);
                parser.expected = null;
                return;
            },
            .declaration => {
                if (scanner.nextNonSpace(parser.source, end) == '.') {
                    parser.setScope(capture_index, .parameter);
                } else {
                    parser.setScope(capture_index, .function);
                    parser.expected = null;
                    parser.parameter_mode = true;
                }
                return;
            },
        };

        const next = scanner.nextNonSpace(parser.source, end);
        const scope: Scope = if (next == ':' and
            (parser.brace_depth > 0 or (parser.dialect == .fsharp and !parser.parameter_mode)))
            .property
        else if (parser.constructor_pending and std.ascii.isUpper(word[0]))
            .constructor
        else if (parser.type_context)
            .type
        else if (parser.parameter_mode)
            .parameter
        else if (scanner.previousNonSpace(parser.source, start) == '.')
            if (next == '(') .function else .property
        else if (next == '(')
            .function
        else if (std.ascii.isUpper(word[0]))
            .constructor
        else
            .variable;
        parser.setScope(capture_index, scope);
        if (scope == .constructor) parser.constructor_pending = false;
    }

    fn refineOperator(parser: *Parser, capture_index: usize, capture: Capture) api.HighlightError!void {
        const operator = parser.source[capture.span.start..capture.span.end];
        if ((operator[0] == '~' or operator[0] == '?') and
            capture.span.end < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[capture.span.end]))
        {
            const end = scanner.identifierEnd(parser.source, capture.span.end, .ascii);
            parser.empty(capture_index);
            parser.suppressed_until = end;
            try parser.sink.add(capture.span.start, end, .parameter);
            return;
        }
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

    fn refinePunctuation(parser: *Parser, capture_index: usize, capture: Capture) api.HighlightError!void {
        const byte = parser.source[capture.span.start];
        if (byte == '[') {
            const fsharp = parser.dialect == .fsharp and std.mem.startsWith(u8, parser.source[capture.span.start..], "[<");
            const ocaml = parser.dialect == .ocaml and std.mem.startsWith(u8, parser.source[capture.span.start..], "[@");
            if (fsharp or ocaml) {
                const closing = if (fsharp) ">]" else "]";
                const close = std.mem.indexOfPos(u8, parser.source, capture.span.start + 2, closing);
                const end = if (close) |at| at + closing.len else parser.source.len;
                parser.empty(capture_index);
                parser.suppressed_until = end;
                try parser.sink.add(capture.span.start, end, .attribute);
                return;
            }
        }
        switch (byte) {
            '{' => parser.brace_depth += 1,
            '}' => parser.brace_depth -|= 1,
            ')', ']' => parser.type_context = false,
            ';' => parser.resetLineState(),
            else => {},
        }
    }

    fn setScope(parser: *Parser, capture_index: usize, scope: Scope) void {
        parser.sink.mutableCaptures()[capture_index].scope = scope;
    }

    fn empty(parser: *Parser, capture_index: usize) void {
        const start = parser.sink.captures()[capture_index].span.start;
        parser.sink.mutableCaptures()[capture_index].span.end = start;
    }

    fn resetLineState(parser: *Parser) void {
        parser.expected = null;
        parser.parameter_mode = false;
        parser.type_context = false;
        parser.constructor_pending = false;
    }
};

fn isIdentifierScope(scope: Scope) bool {
    return switch (scope) {
        .variable, .property, .function, .label => true,
        else => false,
    };
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
