const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "gleam",
    .display_name = "Gleam",
    .kind = .parser_backed,
}, highlight);

const keywords = &.{
    "as",   "assert", "auto",   "case", "const",  "delegate", "echo", "else",
    "fn",   "if",     "import", "let",  "opaque", "panic",    "pub",  "todo",
    "type", "use",
};
const types = &.{ "BitArray", "Bool", "Float", "Int", "List", "Nil", "Result", "String" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try generic.highlight(source, sink, .{
        .line_comments = &.{"//"},
        .keywords = keywords,
        .types = types,
        .booleans = &.{ "True", "False" },
        .classify_identifiers = false,
        .identifier_dash = false,
        .structural_observer = .{
            .context = &parser,
            .before = Parser.before,
            .observe = Parser.observe,
        },
    });
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    expected: ?Scope = null,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    awaiting_parameters: bool = false,
    awaiting_return_type: bool = false,
    type_context: bool = false,

    fn before(_: *anyopaque, _: *usize) api.HighlightError!bool {
        return false;
    }

    fn observe(context: *anyopaque, index: *usize, event: generic.StructuralEvent) api.HighlightError!void {
        const parser: *Parser = @ptrCast(@alignCast(context));
        switch (event) {
            .word => |word| try parser.scanWord(index, word.start, word.end, word.lexical_scope),
            .operator => |operator| parser.observeOperator(parser.source[operator.start..operator.end]),
            .punctuation => |byte| parser.observePunctuation(byte),
            .newline => {
                if (parser.parameter_depth == null) {
                    parser.expected = null;
                    parser.type_context = false;
                }
            },
        }
    }

    fn scanWord(parser: *Parser, index: *usize, start: usize, end: usize, lexical_scope: ?Scope) api.HighlightError!void {
        const word = parser.source[start..end];
        if (lexical_scope == .keyword) {
            if (std.mem.eql(u8, word, "import")) {
                parser.expected = .namespace;
            } else if (std.mem.eql(u8, word, "type")) {
                parser.expected = .type;
            } else if (std.mem.eql(u8, word, "fn")) {
                if (scanner.nextNonSpace(parser.source, end) == '(') {
                    parser.awaiting_parameters = true;
                } else {
                    parser.expected = .function;
                }
            } else if (std.mem.eql(u8, word, "const")) {
                parser.expected = .constant;
            } else if (std.mem.eql(u8, word, "let") or std.mem.eql(u8, word, "use")) {
                parser.expected = .variable;
            }
            return;
        }
        if (lexical_scope == .type or lexical_scope == .boolean or lexical_scope == .constant) return;

        if (parser.expected) |expected| {
            if (expected == .namespace) index.* = importPathEnd(parser.source, start);
            try parser.sink.add(start, index.*, expected);
            parser.expected = null;
            if (expected == .function) parser.awaiting_parameters = true;
            return;
        }

        const next = scanner.nextNonSpace(parser.source, end);
        const previous = scanner.previousNonSpace(parser.source, start);
        if (parser.type_context) {
            try parser.sink.add(start, end, .type);
        } else if (parser.parameter_depth != null and
            (next == ':' or previous == '(' or previous == ','))
        {
            try parser.sink.add(start, end, .parameter);
        } else if (next == ':' and parser.parameter_depth == null) {
            try parser.sink.add(start, end, .property);
        } else if (previous == '.') {
            try parser.sink.add(start, end, if (next == '(') .function else .property);
        } else if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, end, .constructor);
        } else if (next == '(') {
            try parser.sink.add(start, end, .function);
        } else {
            try parser.sink.add(start, end, .variable);
        }
    }

    fn observeOperator(parser: *Parser, operator: []const u8) void {
        if (operator[0] == ':' or (std.mem.eql(u8, operator, "->") and parser.awaiting_return_type)) {
            parser.type_context = true;
            parser.awaiting_return_type = false;
        } else if (operator[0] == '=') {
            parser.type_context = false;
        }
    }

    fn observePunctuation(parser: *Parser, byte: u8) void {
        switch (byte) {
            '(' => {
                parser.paren_depth += 1;
                if (parser.awaiting_parameters) {
                    parser.parameter_depth = parser.paren_depth;
                    parser.awaiting_parameters = false;
                }
            },
            ')' => {
                if (parser.parameter_depth == parser.paren_depth) {
                    parser.parameter_depth = null;
                    parser.awaiting_return_type = true;
                }
                parser.paren_depth -|= 1;
                parser.type_context = false;
            },
            '{' => {
                parser.awaiting_return_type = false;
                parser.type_context = false;
            },
            ',' => parser.type_context = false,
            ';' => {
                parser.expected = null;
                parser.type_context = false;
            },
            else => {},
        }
    }
};

fn importPathEnd(source: []const u8, start: usize) usize {
    var end = scanner.identifierEnd(source, start, .ascii);
    while (end + 1 < source.len and (source[end] == '/' or source[end] == '.') and
        scanner.isAsciiIdentifierStart(source[end + 1]))
    {
        end = scanner.identifierEnd(source, end + 1, .ascii);
    }
    return end;
}
