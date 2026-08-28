const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const nextNonSpace = @import("scanner_support.zig").nextNonSpace;
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;

pub const Config = struct {
    keywords: []const []const u8,
    builtin_types: []const []const u8,
    modifiers: []const []const u8 = &.{},
    type_declarations: []const []const u8 = &.{ "class", "enum", "interface", "record", "struct" },
    namespace_declarations: []const []const u8 = &.{ "namespace", "package" },
    function_declarations: []const []const u8 = &.{},
    variable_declarations: []const []const u8 = &.{},
    capitalized_types: bool = true,
    capitalized_calls_are_constructors: bool = false,
    function_receiver_before_name: bool = false,
};

pub fn highlight(source: []const u8, sink: *api.CaptureSink, config: Config) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink, .config = config };
    defer parser.deinit();
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    config: Config,
    index: usize = 0,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    receiver_depth: ?usize = null,
    expected: ?Scope = null,
    declaration: bool = false,
    pending_function: bool = false,
    known_types: std.ArrayList([]const u8) = .empty,

    fn deinit(parser: *Parser) void {
        parser.known_types.deinit(parser.sink.allocator);
    }

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r', '\n' => parser.index += 1,
            '#' => parser.skipLine(),
            '/' => {
                if (parser.startsWith("//")) {
                    parser.skipLine();
                } else if (parser.startsWith("/*")) {
                    parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |end| end + 2 else parser.source.len;
                } else parser.index += 1;
            },
            '\'', '"', '`' => parser.skipString(parser.source[parser.index]),
            '(' => {
                parser.paren_depth += 1;
                if (parser.config.function_receiver_before_name and parser.expected == .function) {
                    parser.receiver_depth = parser.paren_depth;
                } else if (parser.pending_function) {
                    parser.parameter_depth = parser.paren_depth;
                    parser.pending_function = false;
                }
                parser.index += 1;
            },
            ')' => {
                if (parser.receiver_depth == parser.paren_depth) parser.receiver_depth = null;
                if (parser.parameter_depth == parser.paren_depth) parser.parameter_depth = null;
                parser.paren_depth -|= 1;
                parser.index += 1;
            },
            ';', '{', '}' => {
                parser.expected = null;
                parser.declaration = false;
                parser.pending_function = false;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanIdentifier(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn startsWith(parser: Parser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn skipLine(parser: *Parser) void {
        parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len;
    }

    fn skipString(parser: *Parser, quote: u8) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == quote or (quote != '`' and byte == '\n')) break;
        }
    }

    fn scanIdentifier(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        const next = nextNonSpace(parser.source, parser.index);

        if (parser.expected != null and parser.receiver_depth == null) {
            const scope = parser.expected.?;
            try parser.sink.add(start, parser.index, scope);
            if (scope == .type) try parser.rememberType(word);
            parser.pending_function = scope == .function;
            parser.declaration = scope == .type or scope == .variable;
            parser.expected = null;
            return;
        }
        if (contains(parser.config.type_declarations, word)) {
            parser.expected = .type;
            return;
        }
        if (contains(parser.config.namespace_declarations, word)) {
            parser.expected = .namespace;
            return;
        }
        if (contains(parser.config.function_declarations, word)) {
            parser.expected = .function;
            return;
        }
        if (contains(parser.config.variable_declarations, word)) {
            parser.expected = .variable;
            return;
        }
        if (contains(parser.config.modifiers, word) or contains(parser.config.builtin_types, word)) {
            parser.declaration = true;
            return;
        }
        if (contains(parser.config.keywords, word)) return;

        if (previousMemberOperator(parser.source, start)) {
            try parser.sink.add(start, parser.index, .property);
        } else if (previousNamespaceOperator(parser.source, start)) {
            try parser.sink.add(start, parser.index, .type);
            parser.declaration = true;
        } else if (nextNamespaceOperator(parser.source, parser.index)) {
            try parser.sink.add(start, parser.index, .namespace);
        } else if (next == '(') {
            const constructor = parser.config.capitalized_calls_are_constructors and parser.isKnownType(word);
            try parser.sink.add(start, parser.index, if (constructor) .constructor else .function);
            parser.pending_function = parser.declaration or constructor;
            parser.declaration = false;
        } else if (next == ':' and parser.paren_depth == 0) {
            try parser.sink.add(start, parser.index, .label);
        } else if (parser.config.capitalized_types and std.ascii.isUpper(word[0]) and next != '=' and next != ',' and next != ';') {
            try parser.sink.add(start, parser.index, .type);
            parser.declaration = true;
        } else if (parser.receiver_depth != null) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (parser.parameter_depth != null) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (parser.declaration) {
            try parser.sink.add(start, parser.index, if (parser.parameter_depth != null) .parameter else .variable);
            parser.declaration = next == ',';
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn rememberType(parser: *Parser, word: []const u8) api.HighlightError!void {
        if (!parser.isKnownType(word)) try parser.known_types.append(parser.sink.allocator, word);
    }

    fn isKnownType(parser: Parser, word: []const u8) bool {
        for (parser.known_types.items) |known| if (std.mem.eql(u8, known, word)) return true;
        return false;
    }
};

fn contains(words: []const []const u8, word: []const u8) bool {
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn previousMemberOperator(source: []const u8, before: usize) bool {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return cursor > 0 and (source[cursor - 1] == '.' or (cursor > 1 and source[cursor - 2] == '-' and source[cursor - 1] == '>'));
}

fn previousNamespaceOperator(source: []const u8, before: usize) bool {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return cursor > 1 and source[cursor - 2] == ':' and source[cursor - 1] == ':';
}

fn nextNamespaceOperator(source: []const u8, after: usize) bool {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return cursor + 1 < source.len and source[cursor] == ':' and source[cursor + 1] == ':';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
