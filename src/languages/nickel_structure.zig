const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    brace_depth: usize = 0,
    let_binding_pending: bool = false,
    function_parameters: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "/*")) {
                parser.index = scanner.blockCommentEnd(parser.source, parser.index, parser.source.len);
                continue;
            }
            switch (parser.source[parser.index]) {
                '#' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
                '"' => try parser.scanString(),
                '{' => {
                    parser.brace_depth += 1;
                    parser.index += 1;
                },
                '}' => {
                    parser.brace_depth -|= 1;
                    parser.index += 1;
                },
                '=' => {
                    if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '>') parser.function_parameters = false;
                    parser.index += 1;
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanString(parser: *Parser) api.HighlightError!void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "%{")) {
                const start = parser.index;
                parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index + 2, '}') orelse parser.source.len;
                if (parser.index < parser.source.len) parser.index += 1;
                try parser.sink.add(start, parser.index, .embedded);
                continue;
            }
            if (parser.source[parser.index] == '\\') {
                parser.index = scanner.escapeEnd(parser.source, parser.index);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
            if (byte == '"' or byte == '\n') break;
        }
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        const word = parser.source[start..parser.index];
        if (std.mem.eql(u8, word, "let")) {
            parser.let_binding_pending = true;
            return;
        }
        if (std.mem.eql(u8, word, "rec") and parser.let_binding_pending) return;
        if (std.mem.eql(u8, word, "fun")) {
            parser.function_parameters = true;
            return;
        }
        if (isKeyword(word) or isBuiltinType(word)) return;

        const next = scanner.nextNonSpace(parser.source, parser.index);
        if (parser.let_binding_pending) {
            const scope: @import("../scope.zig").Scope = if (bindingIsFunction(parser.source, parser.index)) .function else .variable;
            try parser.sink.add(start, parser.index, scope);
            parser.let_binding_pending = false;
        } else if (parser.function_parameters) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (parser.brace_depth > 0 and (next == '=' or next == '|')) {
            try parser.sink.add(start, parser.index, .property);
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else if (next == '.') {
            try parser.sink.add(start, parser.index, .namespace);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }
};

fn bindingIsFunction(source: []const u8, after: usize) bool {
    var index = after;
    while (index < source.len and std.ascii.isWhitespace(source[index])) index += 1;
    if (index >= source.len or source[index] != '=') return false;
    index += 1;
    while (index < source.len and std.ascii.isWhitespace(source[index])) index += 1;
    return index + 3 <= source.len and std.mem.eql(u8, source[index .. index + 3], "fun") and
        (index + 3 == source.len or !std.ascii.isAlphanumeric(source[index + 3]));
}

fn isKeyword(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "assume", "default", "doc", "else", "enum", "export", "forall", "force", "if", "import", "in", "include", "match", "merge", "not_exported", "optional", "or", "priority", "rec", "serialize", "then" });
}

fn isBuiltinType(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "Array", "Bool", "Dyn", "Enum", "Number", "Record", "String" });
}
