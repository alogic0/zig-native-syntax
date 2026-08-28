const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const composition = @import("../composition.zig");
const g = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "typst",
    .display_name = "Typst",
    .kind = .composed,
    .support_level = .verified_structural,
}, highlight);

const code_backend: api.Backend = .init(.{
    .canonical_name = "typst-code",
    .display_name = "Typst code",
    .kind = .parser_backed,
}, highlightCode);

const math_backend: api.Backend = .init(.{
    .canonical_name = "typst-math",
    .display_name = "Typst math",
    .kind = .lexical,
}, highlightMath);

const code_keywords = &.{ "and", "as", "break", "context", "else", "for", "if", "import", "in", "include", "let", "not", "or", "return", "set", "show", "while" };
const code_types = &.{ "array", "bool", "bytes", "content", "datetime", "decimal", "dictionary", "duration", "float", "function", "int", "label", "length", "module", "none", "ratio", "relative", "str", "type" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: MarkupParser = .{ .source = source, .sink = sink };
    try parser.run();
}

fn highlightCode(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"//"},
        .block_comments = &.{.{ .open = "/*", .close = "*/" }},
        .keywords = code_keywords,
        .types = code_types,
        .constants = &.{ "auto", "none" },
        .classify_identifiers = false,
        .identifier_dash = false,
    });
    var parser: CodeParser = .{ .source = source, .sink = sink };
    try parser.run();
}

fn highlightMath(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: MathParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const MarkupParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    line_start: usize = 0,

    fn run(parser: *MarkupParser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.startsWith("//")) {
                try parser.scanLineComment();
            } else if (parser.startsWith("/*")) {
                try parser.scanBlockComment();
            } else switch (parser.source[parser.index]) {
                '\n' => {
                    parser.index += 1;
                    parser.line_start = parser.index;
                },
                '`' => try parser.scanRaw(),
                '$' => try parser.scanMath(),
                '#' => try parser.scanCodeExpression(),
                '<' => try parser.scanLabel(),
                '@' => try parser.scanReference(),
                '\\' => try parser.scanEscape(),
                '=' => {
                    if (parser.onlyIndentBefore()) try parser.sink.add(parser.index, parser.index + 1, .keyword);
                    parser.index += 1;
                },
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanCodeExpression(parser: *MarkupParser) api.HighlightError!void {
        const marker = parser.index;
        try parser.sink.add(marker, marker + 1, .special);
        parser.index += 1;
        while (parser.index < parser.source.len and (parser.source[parser.index] == ' ' or parser.source[parser.index] == '\t')) parser.index += 1;
        const start = parser.index;
        if (start >= parser.source.len) return;

        var word_end = start;
        while (word_end < parser.source.len and isIdentifierContinue(parser.source[word_end])) word_end += 1;
        const word = parser.source[start..word_end];
        var end = word_end;
        if (parser.source[start] == '{') {
            end = matchingDelimiter(parser.source, start, '{', '}') orelse parser.source.len;
            if (end < parser.source.len) end += 1;
        } else if (isStatementKeyword(word)) {
            end = scanner.lineEnd(parser.source, start, parser.source.len);
        } else {
            var cursor = word_end;
            while (cursor < parser.source.len and (parser.source[cursor] == '.' or isIdentifierContinue(parser.source[cursor]))) cursor += 1;
            if (cursor < parser.source.len and parser.source[cursor] == '(') {
                end = matchingDelimiter(parser.source, cursor, '(', ')') orelse parser.source.len;
                if (end < parser.source.len) end += 1;
            } else {
                end = cursor;
            }
        }
        if (end > start) try composition.highlightEmbedded(parser.source, .{ .start = start, .end = end }, code_backend, parser.sink);
        parser.index = @max(end, start + 1);
    }

    fn scanMath(parser: *MarkupParser) api.HighlightError!void {
        const open = parser.index;
        parser.index += 1;
        const start = parser.index;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index = scanner.escapeEnd(parser.source, parser.index);
            } else if (parser.source[parser.index] == '$') {
                break;
            } else {
                parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
            }
        }
        try parser.sink.add(open, open + 1, .special);
        if (start < parser.index) try composition.highlightEmbedded(parser.source, .{ .start = start, .end = parser.index }, math_backend, parser.sink);
        if (parser.index < parser.source.len) {
            try parser.sink.add(parser.index, parser.index + 1, .special);
            parser.index += 1;
        }
    }

    fn scanRaw(parser: *MarkupParser) api.HighlightError!void {
        const start = parser.index;
        const fenced = parser.startsWith("```");
        const delimiter = if (fenced) "```" else "`";
        parser.index += delimiter.len;
        if (fenced) {
            const language_start = parser.index;
            parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
            if (parser.index > language_start) try parser.sink.add(language_start, parser.index, .attribute);
            if (parser.index < parser.source.len) parser.index += 1;
        }
        const close = std.mem.indexOfPos(u8, parser.source, parser.index, delimiter);
        parser.index = if (close) |position| position + delimiter.len else parser.source.len;
        try parser.sink.add(start, parser.index, .string);
    }

    fn scanLabel(parser: *MarkupParser) api.HighlightError!void {
        const start = parser.index;
        const close = std.mem.indexOfScalarPos(u8, parser.source, start + 1, '>') orelse {
            parser.index += 1;
            return;
        };
        if (std.mem.indexOfScalar(u8, parser.source[start + 1 .. close], '\n') != null) {
            parser.index += 1;
            return;
        }
        parser.index = close + 1;
        try parser.sink.add(start, parser.index, .label);
    }

    fn scanReference(parser: *MarkupParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (isIdentifierContinue(parser.source[parser.index]) or parser.source[parser.index] == ':' or parser.source[parser.index] == '.')) parser.index += 1;
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .label);
    }

    fn scanEscape(parser: *MarkupParser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.escapeEnd(parser.source, parser.index);
        try parser.sink.add(start, parser.index, .escape);
    }

    fn scanLineComment(parser: *MarkupParser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.lineEnd(parser.source, start, parser.source.len);
        try parser.sink.add(start, parser.index, .comment);
    }

    fn scanBlockComment(parser: *MarkupParser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.blockCommentEnd(parser.source, start, parser.source.len);
        try parser.sink.add(start, parser.index, .comment);
    }

    fn onlyIndentBefore(parser: MarkupParser) bool {
        for (parser.source[parser.line_start..parser.index]) |byte| if (byte != ' ' and byte != '\t') return false;
        return true;
    }

    fn startsWith(parser: MarkupParser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }
};

const CodeParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expected_binding: bool = false,
    awaiting_parameters: bool = false,
    parameter_depth: ?usize = null,
    paren_depth: usize = 0,

    fn run(parser: *CodeParser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "//")) {
                parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
            } else if (std.mem.startsWith(u8, parser.source[parser.index..], "/*")) {
                parser.index = scanner.blockCommentEnd(parser.source, parser.index, parser.source.len);
            } else switch (parser.source[parser.index]) {
                '\'', '"' => parser.index = scanner.quotedEnd(parser.source, parser.index, parser.source[parser.index], true),
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
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanWord(parser: *CodeParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (parser.expected_binding) {
            const function_binding = scanner.nextNonSpace(parser.source, parser.index) == '(';
            try parser.sink.add(start, parser.index, if (function_binding) .function else .variable);
            parser.awaiting_parameters = function_binding;
            parser.expected_binding = false;
        } else if (std.mem.eql(u8, word, "let")) {
            parser.expected_binding = true;
        } else if (wordIs(word, code_keywords) or wordIs(word, code_types) or wordIs(word, &.{ "auto", "none", "true", "false" })) {
            return;
        } else if (parser.parameter_depth != null and isParameterPosition(parser.source, start)) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == ':') {
            try parser.sink.add(start, parser.index, .property);
        } else if (previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, if (scanner.nextNonSpace(parser.source, parser.index) == '(') .function else .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }
};

const MathParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,

    fn run(parser: *MathParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '0'...'9' => try parser.scanNumber(),
            'a'...'z', 'A'...'Z' => try parser.scanWord(),
            '"' => try parser.scanString(),
            '+', '-', '*', '/', '=', '<', '>', '^', '_' => {
                try parser.sink.add(parser.index, parser.index + 1, .operator);
                parser.index += 1;
            },
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *MathParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isAlphanumeric(parser.source[parser.index]) or parser.source[parser.index] == '-')) parser.index += 1;
        const word = parser.source[start..parser.index];
        const scope: Scope = if (wordIs(word, &.{ "attach", "cases", "limits", "mat", "sqrt", "sum", "vec" })) .keyword else .variable;
        try parser.sink.add(start, parser.index, scope);
    }

    fn scanNumber(parser: *MathParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and (std.ascii.isDigit(parser.source[parser.index]) or parser.source[parser.index] == '.')) parser.index += 1;
        try parser.sink.add(start, parser.index, .number);
    }

    fn scanString(parser: *MathParser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.quotedEnd(parser.source, start, '"', true);
        try parser.sink.add(start, parser.index, .string);
    }
};

fn matchingDelimiter(source: []const u8, open: usize, opening: u8, closing: u8) ?usize {
    var cursor = open + 1;
    var depth: usize = 1;
    while (cursor < source.len) {
        if (source[cursor] == '"' or source[cursor] == '\'') {
            cursor = scanner.quotedEnd(source, cursor, source[cursor], true);
        } else if (std.mem.startsWith(u8, source[cursor..], "//")) {
            cursor = scanner.lineEnd(source, cursor, source.len);
        } else if (std.mem.startsWith(u8, source[cursor..], "/*")) {
            cursor = scanner.blockCommentEnd(source, cursor, source.len);
        } else if (source[cursor] == opening) {
            depth += 1;
            cursor += 1;
        } else if (source[cursor] == closing) {
            depth -= 1;
            if (depth == 0) return cursor;
            cursor += 1;
        } else {
            cursor += scanner.validUtf8Length(source[cursor..]);
        }
    }
    return null;
}

fn isStatementKeyword(word: []const u8) bool {
    return wordIs(word, &.{ "for", "if", "import", "include", "let", "set", "show", "while" });
}

fn isParameterPosition(source: []const u8, start: usize) bool {
    const previous = previousNonSpace(source, start) orelse return false;
    return previous == '(' or previous == ',';
}

fn previousNonSpace(source: []const u8, before: usize) ?u8 {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return if (cursor > 0) source[cursor - 1] else null;
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}

fn wordIs(word: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| if (std.mem.eql(u8, word, candidate)) return true;
    return false;
}
