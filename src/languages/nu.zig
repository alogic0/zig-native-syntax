const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const g = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "nu",
    .display_name = "Nushell",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const keywords = &.{ "alias", "break", "const", "def", "else", "export", "extern", "for", "if", "in", "let", "loop", "match", "module", "mut", "return", "try", "use", "while" };
const types = &.{ "any", "binary", "bool", "cell-path", "closure", "datetime", "duration", "error", "filesize", "float", "glob", "int", "list", "nothing", "number", "path", "range", "record", "string", "table" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .keywords = keywords,
        .types = types,
        .quotes = "\"'`",
        .classify_identifiers = false,
    });
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    command_position: bool = true,
    expected: ?Scope = null,
    awaiting_signature: bool = false,
    signature_depth: ?usize = null,
    bracket_depth: usize = 0,
    type_mode: bool = false,
    binding_assignment: bool = false,
    closure_parameters: bool = false,
    command_family: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r' => parser.index += 1,
            '\n', ';' => {
                parser.command_position = true;
                parser.command_family = false;
                parser.type_mode = false;
                parser.index += 1;
            },
            '#' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
            '\'', '"', '`' => parser.skipString(parser.source[parser.index]),
            '$' => try parser.scanVariable(),
            '^' => try parser.scanExternalCommand(),
            '-' => {
                if (std.mem.startsWith(u8, parser.source[parser.index..], "->")) {
                    parser.type_mode = true;
                    parser.index += 2;
                } else try parser.scanFlag();
            },
            '[' => {
                parser.bracket_depth += 1;
                if (parser.awaiting_signature) {
                    parser.signature_depth = parser.bracket_depth;
                    parser.awaiting_signature = false;
                }
                parser.index += 1;
            },
            ']' => {
                if (parser.signature_depth == parser.bracket_depth) parser.signature_depth = null;
                parser.bracket_depth -|= 1;
                parser.type_mode = false;
                parser.index += 1;
            },
            '{' => {
                parser.type_mode = false;
                parser.command_position = true;
                parser.index += 1;
            },
            '}' => {
                parser.command_position = false;
                parser.index += 1;
            },
            '|' => {
                if (previousNonSpace(parser.source, parser.index) == '{' or parser.closure_parameters) {
                    parser.closure_parameters = !parser.closure_parameters;
                    parser.command_position = !parser.closure_parameters;
                } else {
                    parser.command_position = true;
                    parser.command_family = false;
                }
                parser.index += 1;
            },
            '(' => {
                parser.command_position = true;
                parser.index += 1;
            },
            ')' => {
                parser.command_position = false;
                parser.index += 1;
            },
            ':' => {
                if (parser.signature_depth != null) parser.type_mode = true;
                parser.index += 1;
            },
            ',' => {
                parser.type_mode = false;
                parser.index += 1;
            },
            '=' => {
                if (parser.binding_assignment) parser.command_position = true;
                parser.binding_assignment = false;
                parser.type_mode = false;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isWordContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];

        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.expected = null;
            if (scope == .function) parser.awaiting_signature = true;
            if (scope == .variable) parser.binding_assignment = true;
            parser.command_position = false;
            return;
        }
        if (parser.type_mode) {
            try parser.sink.add(start, parser.index, .type);
            return;
        }
        if (wordIs(word, &.{ "def", "extern" })) {
            parser.expected = .function;
            parser.command_position = false;
            return;
        }
        if (wordIs(word, &.{ "let", "mut", "const", "for" })) {
            parser.expected = .variable;
            parser.command_position = false;
            return;
        }
        if (std.mem.eql(u8, word, "module")) {
            parser.expected = .namespace;
            parser.command_position = false;
            return;
        }
        if (isKeyword(word) or isLiteral(word)) {
            parser.command_position = false;
            return;
        }
        if (parser.closure_parameters or (parser.signature_depth != null and isParameterPosition(parser.source, start))) {
            try parser.sink.add(start, parser.index, .parameter);
            parser.command_position = false;
        } else if (scanner.nextNonSpace(parser.source, parser.index) == ':') {
            try parser.sink.add(start, parser.index, .property);
            parser.command_position = false;
        } else if (parser.command_position or parser.command_family) {
            try parser.sink.add(start, parser.index, .function);
            if (isBuiltinCommand(word)) try parser.sink.add(start, parser.index, .builtin);
            parser.command_family = isCommandFamily(word);
            parser.command_position = false;
        } else if (isType(word)) {
            return;
        } else if (previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        }
    }

    fn scanVariable(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '"') {
            parser.skipString('"');
            try parser.sink.add(start, parser.index, .string);
            parser.command_position = false;
            return;
        }
        while (parser.index < parser.source.len and isWordContinue(parser.source[parser.index])) parser.index += 1;
        while (parser.index < parser.source.len and parser.source[parser.index] == '.') {
            parser.index += 1;
            while (parser.index < parser.source.len and isWordContinue(parser.source[parser.index])) parser.index += 1;
        }
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .variable);
        parser.command_position = false;
    }

    fn scanFlag(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '-') parser.index += 1;
        while (parser.index < parser.source.len and isWordContinue(parser.source[parser.index])) parser.index += 1;
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .attribute);
        parser.command_position = false;
    }

    fn scanExternalCommand(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and !std.ascii.isWhitespace(parser.source[parser.index]) and
            std.mem.indexOfScalar(u8, ";|(){}[]", parser.source[parser.index]) == null)
        {
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .function);
        parser.command_position = false;
    }

    fn skipString(parser: *Parser, quote: u8) void {
        parser.index = scanner.quotedEnd(parser.source, parser.index, quote, quote != '`');
    }
};

fn isParameterPosition(source: []const u8, start: usize) bool {
    const previous = previousNonSpace(source, start) orelse return false;
    return previous == '[' or previous == ',' or (start >= 3 and std.mem.eql(u8, source[start - 3 .. start], "..."));
}

const previousNonSpace = scanner.previousNonSpace;

fn isWordContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
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

fn isCommandFamily(word: []const u8) bool {
    return wordIs(word, &.{ "bytes", "date", "from", "into", "math", "path", "random", "str", "to", "url" });
}

fn isBuiltinCommand(word: []const u8) bool {
    return wordIs(word, &.{ "all", "any", "collect", "each", "enumerate", "filter", "first", "flatten", "get", "glob", "lines", "open", "reduce", "select", "sort-by", "where", "wrap" }) or isCommandFamily(word);
}
