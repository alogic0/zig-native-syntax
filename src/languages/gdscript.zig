const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const g = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "gdscript",
    .display_name = "GDScript",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const keywords = &.{ "and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue", "elif", "else", "enum", "extends", "for", "func", "if", "in", "is", "match", "not", "or", "pass", "return", "signal", "static", "var", "while", "yield" };
const types = &.{ "Array", "Basis", "bool", "Callable", "Color", "Dictionary", "float", "int", "Node", "Node2D", "Node3D", "NodePath", "Object", "PackedByteArray", "Rect2", "String", "StringName", "Transform2D", "Transform3D", "Vector2", "Vector2i", "Vector3", "Vector3i", "void" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .keywords = keywords,
        .types = types,
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
    type_annotation_allowed: bool = false,
    enum_depth: ?usize = null,
    brace_depth: usize = 0,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
            '\'', '"' => parser.skipString(parser.source[parser.index]),
            '@' => try parser.scanAnnotation(),
            '$', '%' => try parser.scanNodePath(),
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
            '{' => {
                if (parser.enum_depth == 0 and parser.expected == .type) parser.expected = null;
                parser.brace_depth += 1;
                if (parser.enum_depth != null and parser.enum_depth.? == 0) parser.enum_depth = parser.brace_depth;
                parser.index += 1;
            },
            '}' => {
                if (parser.enum_depth == parser.brace_depth) parser.enum_depth = null;
                parser.brace_depth -|= 1;
                parser.index += 1;
            },
            ':' => {
                if (parser.type_annotation_allowed and scanner.nextNonSpace(parser.source, parser.index + 1) != '=') parser.expect_type = true;
                parser.type_annotation_allowed = false;
                parser.index += 1;
            },
            '\n', ';' => {
                parser.expect_type = false;
                parser.type_annotation_allowed = false;
                parser.index += 1;
            },
            '-' => {
                if (std.mem.startsWith(u8, parser.source[parser.index..], "->")) {
                    parser.expect_type = true;
                    parser.index += 2;
                } else parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];

        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            if (scope == .function) parser.awaiting_parameters = true;
            if (scope == .variable) parser.type_annotation_allowed = true;
            return;
        }
        if (parser.expect_type) {
            try parser.sink.add(start, parser.index, .type);
            parser.expect_type = false;
            return;
        }
        if (wordIs(word, &.{ "class", "class_name", "extends" })) {
            parser.expected = .type;
            return;
        }
        if (std.mem.eql(u8, word, "enum")) {
            parser.expected = .type;
            parser.enum_depth = 0;
            return;
        }
        if (wordIs(word, &.{ "func", "signal" })) {
            parser.expected = .function;
            return;
        }
        if (wordIs(word, &.{ "var", "const" })) {
            parser.expected = .variable;
            return;
        }
        if (isKeyword(word) or isType(word) or isLiteral(word)) return;

        if (parser.enum_depth != null and parser.brace_depth == parser.enum_depth.?) {
            try parser.sink.add(start, parser.index, .constant);
        } else if (parser.parameter_depth != null and isParameterPosition(parser.source, start)) {
            try parser.sink.add(start, parser.index, .parameter);
            parser.type_annotation_allowed = true;
        } else if (previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, if (scanner.nextNonSpace(parser.source, parser.index) == '(') .function else .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (wordIs(word, &.{ "self", "super" })) {
            try parser.sink.add(start, parser.index, .builtin);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanAnnotation(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .attribute);
    }

    fn scanNodePath(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and !std.ascii.isWhitespace(parser.source[parser.index]) and
            std.mem.indexOfScalar(u8, ";,(){}[]", parser.source[parser.index]) == null)
        {
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        try parser.sink.add(start, parser.index, .string);
    }

    fn skipString(parser: *Parser, quote: u8) void {
        const triple = parser.index + 2 < parser.source.len and parser.source[parser.index + 1] == quote and parser.source[parser.index + 2] == quote;
        if (!triple) {
            parser.index = scanner.quotedEnd(parser.source, parser.index, quote, true);
            return;
        }
        parser.index += 3;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
            } else if (parser.index + 2 < parser.source.len and parser.source[parser.index] == quote and parser.source[parser.index + 1] == quote and parser.source[parser.index + 2] == quote) {
                parser.index += 3;
                return;
            } else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
    }
};

fn isParameterPosition(source: []const u8, start: usize) bool {
    const previous = previousNonSpace(source, start) orelse return false;
    return previous == '(' or previous == ',';
}

const previousNonSpace = scanner.previousNonSpace;

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

const wordIs = scanner.wordIs;

fn isKeyword(word: []const u8) bool {
    return wordIs(word, keywords);
}

fn isType(word: []const u8) bool {
    return wordIs(word, types);
}

fn isLiteral(word: []const u8) bool {
    return wordIs(word, &.{ "true", "false", "null" });
}
