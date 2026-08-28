const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub const Dialect = enum { elm, purescript };

pub fn highlight(source: []const u8, sink: *api.CaptureSink, dialect: Dialect) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink, .dialect = dialect };
    try parser.run();
}

const Declaration = enum { none, signature, equation };

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    dialect: Dialect,
    index: usize = 0,
    line_start: usize = 0,
    brace_depth: usize = 0,
    expected_namespace: bool = false,
    expected_type: bool = false,
    type_context: bool = false,
    equation_parameters: bool = false,
    data_declaration: bool = false,
    constructor_pending: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "--")) {
                parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                continue;
            }
            if (std.mem.startsWith(u8, parser.source[parser.index..], "{-")) {
                parser.skipNestedComment();
                continue;
            }
            switch (parser.source[parser.index]) {
                '"', '\'' => parser.index = scanner.quotedEnd(parser.source, parser.index, parser.source[parser.index], true),
                '{' => {
                    parser.brace_depth += 1;
                    parser.index += 1;
                },
                '}' => {
                    parser.brace_depth -|= 1;
                    parser.index += 1;
                },
                ':' => {
                    if (parser.dialect == .elm or
                        (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == ':'))
                    {
                        parser.type_context = true;
                        parser.equation_parameters = false;
                    }
                    parser.index += if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == ':') 2 else 1;
                },
                '=' => {
                    parser.constructor_pending = parser.data_declaration;
                    parser.type_context = false;
                    parser.equation_parameters = false;
                    parser.index += 1;
                },
                '|' => {
                    parser.constructor_pending = parser.data_declaration;
                    parser.type_context = false;
                    parser.index += 1;
                },
                '\n' => {
                    parser.index += 1;
                    parser.line_start = parser.index;
                    parser.expected_namespace = false;
                    parser.expected_type = false;
                    parser.type_context = false;
                    parser.equation_parameters = false;
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
        const first_on_line = scanner.onlyIndentBefore(parser.source, parser.line_start, start);

        if (parser.expected_namespace) {
            parser.index = scanner.qualifiedIdentifierEnd(parser.source, start, ".", .apostrophe, .identifier);
            try parser.sink.add(start, parser.index, .namespace);
            parser.expected_namespace = false;
            return;
        }
        if (parser.expected_type) {
            if (parser.dialect == .elm and std.mem.eql(u8, word, "alias")) {
                parser.data_declaration = false;
                return;
            }
            try parser.sink.add(start, parser.index, .type);
            parser.expected_type = false;
            return;
        }
        if (std.mem.eql(u8, word, "module") or std.mem.eql(u8, word, "import") or
            std.mem.eql(u8, word, "as"))
        {
            parser.expected_namespace = true;
            return;
        }
        if (std.mem.eql(u8, word, "type")) {
            parser.expected_type = true;
            parser.data_declaration = parser.dialect == .elm;
            return;
        }
        if (parser.dialect == .purescript and
            (std.mem.eql(u8, word, "data") or std.mem.eql(u8, word, "newtype") or
                std.mem.eql(u8, word, "class")))
        {
            parser.expected_type = true;
            parser.data_declaration = !std.mem.eql(u8, word, "class");
            return;
        }
        if (isKeyword(word, parser.dialect) or isLiteral(word, parser.dialect)) return;

        const declaration = if (first_on_line) lineDeclaration(parser.source, parser.index, parser.dialect) else .none;
        if (parser.brace_depth > 0 and nextIsSignature(parser.source, parser.index, parser.dialect)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (parser.brace_depth > 0 and scanner.nextNonSpace(parser.source, parser.index) == '=') {
            try parser.sink.add(start, parser.index, .property);
        } else if (declaration != .none and std.ascii.isLower(word[0])) {
            try parser.sink.add(start, parser.index, .function);
            parser.equation_parameters = declaration == .equation;
            parser.data_declaration = false;
        } else if (parser.type_context and std.ascii.isUpper(word[0])) {
            parser.index = scanner.qualifiedIdentifierEnd(parser.source, start, ".", .apostrophe, .identifier);
            try parser.sink.add(start, parser.index, .type);
        } else if (parser.constructor_pending and std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .constructor);
            parser.constructor_pending = false;
        } else if (parser.equation_parameters and std.ascii.isLower(word[0])) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '.' and std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .namespace);
        } else if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .constructor);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
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
};

fn lineDeclaration(source: []const u8, after: usize, dialect: Dialect) Declaration {
    const end = scanner.lineEnd(source, after, source.len);
    const tail = source[after..end];
    if (dialect == .purescript) {
        if (std.mem.indexOf(u8, tail, "::") != null) return .signature;
    } else if (std.mem.indexOfScalar(u8, tail, ':') != null) return .signature;
    if (std.mem.indexOfScalar(u8, tail, '=') != null) return .equation;
    return .none;
}

fn nextIsSignature(source: []const u8, after: usize, dialect: Dialect) bool {
    var index = after;
    while (index < source.len and (source[index] == ' ' or source[index] == '\t')) index += 1;
    if (index >= source.len or source[index] != ':') return false;
    return dialect == .elm or (index + 1 < source.len and source[index + 1] == ':');
}

fn isKeyword(word: []const u8, dialect: Dialect) bool {
    const common = &.{ "as", "case", "else", "if", "import", "in", "let", "module", "of", "then", "type" };
    if (scanner.wordIs(word, common)) return true;
    return if (dialect == .elm)
        scanner.wordIs(word, &.{ "alias", "exposing", "port" })
    else
        scanner.wordIs(word, &.{ "class", "data", "derive", "do", "forall", "foreign", "instance", "newtype", "where" });
}

fn isLiteral(word: []const u8, dialect: Dialect) bool {
    return if (dialect == .elm)
        scanner.wordIs(word, &.{ "True", "False", "Nothing", "Just", "Ok", "Err" })
    else
        scanner.wordIs(word, &.{ "true", "false", "Nothing", "Just", "Left", "Right" });
}
