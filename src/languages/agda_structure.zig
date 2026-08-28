const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Block = enum { none, data, record };

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    block: Block = .none,
    block_indent: usize = 0,
    record_fields: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            const line_start = parser.index;
            const line_end = scanner.lineEnd(parser.source, line_start, parser.source.len);
            try parser.scanLine(line_start, line_end);
            parser.index = if (line_end < parser.source.len) line_end + 1 else line_end;
        }
    }

    fn scanLine(parser: *Parser, line_start: usize, line_end: usize) api.HighlightError!void {
        var index = line_start;
        while (index < line_end and (parser.source[index] == ' ' or parser.source[index] == '\t')) index += 1;
        const indent = index - line_start;
        if (index >= line_end or std.mem.startsWith(u8, parser.source[index..line_end], "--")) return;

        var expected_namespace = false;
        var expected_type = false;
        var field_line = false;
        var declaration_seen = false;
        var equation_parameters = false;
        var type_context = false;
        const has_signature = std.mem.indexOfScalar(u8, parser.source[index..line_end], ':') != null;
        const has_equation = std.mem.indexOfScalar(u8, parser.source[index..line_end], '=') != null;

        if (parser.block != .none and indent <= parser.block_indent and !startsWithWord(parser.source[index..line_end], "where")) {
            parser.block = .none;
            parser.record_fields = false;
        }

        while (index < line_end) switch (parser.source[index]) {
            '"' => index = scanner.quotedEnd(parser.source, index, '"', true),
            '-' => {
                if (index + 1 < line_end and parser.source[index + 1] == '-') return;
                index += 1;
            },
            ':' => {
                type_context = true;
                equation_parameters = false;
                index += 1;
            },
            '=' => {
                equation_parameters = false;
                type_context = false;
                index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => {
                const start = index;
                index = scanner.identifierEnd(parser.source, index, .apostrophe);
                const word = parser.source[start..index];
                if (expected_namespace) {
                    index = scanner.qualifiedIdentifierEnd(parser.source, start, ".", .apostrophe, .identifier);
                    try parser.sink.add(start, index, .namespace);
                    expected_namespace = false;
                } else if (expected_type) {
                    try parser.sink.add(start, index, .type);
                    expected_type = false;
                    declaration_seen = true;
                } else if (std.mem.eql(u8, word, "module") or std.mem.eql(u8, word, "import")) {
                    expected_namespace = true;
                } else if (std.mem.eql(u8, word, "data")) {
                    expected_type = true;
                    parser.block = .data;
                    parser.block_indent = indent;
                    parser.record_fields = false;
                } else if (std.mem.eql(u8, word, "record")) {
                    expected_type = true;
                    parser.block = .record;
                    parser.block_indent = indent;
                    parser.record_fields = false;
                } else if (std.mem.eql(u8, word, "field")) {
                    field_line = true;
                    parser.record_fields = parser.block == .record;
                } else if (isKeyword(word) or isBuiltinType(word)) {
                    if (isBuiltinType(word)) try parser.sink.add(start, index, .type);
                } else if (!declaration_seen and parser.block == .data and indent > parser.block_indent and has_signature) {
                    try parser.sink.add(start, index, .constructor);
                    declaration_seen = true;
                } else if (!declaration_seen and parser.block == .record and indent > parser.block_indent and (field_line or parser.record_fields) and has_signature) {
                    try parser.sink.add(start, index, .property);
                    declaration_seen = true;
                } else if (!declaration_seen and (has_signature or has_equation)) {
                    try parser.sink.add(start, index, .function);
                    declaration_seen = true;
                    equation_parameters = has_equation;
                } else if (equation_parameters) {
                    try parser.sink.add(start, index, .parameter);
                } else if (type_context and std.ascii.isUpper(word[0])) {
                    try parser.sink.add(start, index, .type);
                }
            },
            else => index += scanner.validUtf8Length(parser.source[index..]),
        };
    }
};

fn startsWithWord(source: []const u8, word: []const u8) bool {
    return std.mem.startsWith(u8, source, word) and (source.len == word.len or std.ascii.isWhitespace(source[word.len]));
}

fn isKeyword(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "abstract", "constructor", "do", "eta-equality", "hiding", "in", "inductive", "instance", "let", "macro", "mutual", "open", "overlap", "pattern", "postulate", "primitive", "private", "public", "rewrite", "syntax", "tactic", "using", "variable", "where", "with" });
}

fn isBuiltinType(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "Level", "Prop", "Set" });
}
