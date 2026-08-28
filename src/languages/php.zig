const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const Span = @import("../capture.zig").Span;
const Scope = @import("../scope.zig").Scope;
const g = @import("generic.zig");
const markup = @import("component_markup.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "php",
    .display_name = "PHP",
    .kind = .composed,
    .support_level = .verified_structural,
}, highlight);

const php_code_backend: api.Backend = .init(.{
    .canonical_name = "php-code",
    .display_name = "PHP code",
    .kind = .parser_backed,
}, highlightPhpCode);

const markup_backend: api.Backend = .init(.{
    .canonical_name = "php-markup",
    .display_name = "PHP markup",
    .kind = .lexical,
}, highlightMarkup);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    if (std.mem.indexOf(u8, source, "<?") == null) {
        try composition.highlightEmbedded(source, .{ .start = 0, .end = source.len }, php_code_backend, sink);
        return;
    }

    var cursor: usize = 0;
    while (std.mem.indexOfPos(u8, source, cursor, "<?")) |open| {
        try highlightRegion(source, .{ .start = cursor, .end = open }, markup_backend, sink);

        const marker_end = phpOpenEnd(source, open);
        try sink.add(open, marker_end, .special);
        const close = phpClose(source, marker_end);
        try highlightRegion(source, .{ .start = marker_end, .end = close }, php_code_backend, sink);
        if (close == source.len) return;
        try sink.add(close, close + 2, .special);
        cursor = close + 2;
    }
    try highlightRegion(source, .{ .start = cursor, .end = source.len }, markup_backend, sink);
}

fn highlightRegion(source: []const u8, region: Span, nested: api.Backend, sink: *api.CaptureSink) api.HighlightError!void {
    if (region.start != region.end) try composition.highlightEmbedded(source, region, nested, sink);
}

fn phpOpenEnd(source: []const u8, open: usize) usize {
    if (std.mem.startsWith(u8, source[open..], "<?=")) return open + 3;
    if (source.len >= open + 5 and std.ascii.eqlIgnoreCase(source[open + 2 .. open + 5], "php")) return open + 5;
    return open + 2;
}

fn highlightMarkup(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try markup.highlight(source, sink, false);
}

fn highlightPhpCode(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{ "//", "#" },
        .block_comments = &.{.{ .open = "/*", .close = "*/" }},
        .keywords = &.{ "abstract", "and", "array", "as", "break", "callable", "case", "catch", "class", "clone", "const", "continue", "declare", "default", "do", "echo", "else", "elseif", "empty", "endfor", "endforeach", "endif", "endswitch", "endwhile", "enum", "extends", "final", "finally", "fn", "for", "foreach", "function", "global", "goto", "if", "implements", "include", "include_once", "instanceof", "interface", "match", "namespace", "new", "or", "print", "private", "protected", "public", "readonly", "require", "require_once", "return", "static", "switch", "throw", "trait", "try", "unset", "use", "while", "xor", "yield" },
        .types = &.{ "bool", "float", "int", "iterable", "mixed", "never", "object", "string", "void" },
        .case_insensitive = true,
        .identifier_dash = false,
        .strings_stop_at_newline = false,
        .angle_heredoc = true,
        .hash_bracket_attribute = true,
    });
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    expected: ?Scope = null,
    pending_parameters: bool = false,
    parameter_depth: ?usize = null,
    paren_depth: usize = 0,
    namespace_mode: bool = false,
    attribute_depth: usize = 0,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => {
                if (parser.startsWith("#[")) {
                    parser.attribute_depth += 1;
                    parser.index += 2;
                } else {
                    parser.skipLine();
                }
            },
            '/' => {
                if (parser.startsWith("//")) {
                    parser.skipLine();
                } else if (parser.startsWith("/*")) {
                    parser.skipBlock();
                } else {
                    parser.index += 1;
                }
            },
            '<' => {
                if (parser.startsWith("<<<")) {
                    parser.skipHeredoc();
                } else {
                    parser.index += 1;
                }
            },
            '\'', '"', '`' => parser.skipString(parser.source[parser.index]),
            '(' => {
                parser.paren_depth += 1;
                if (parser.expected == .function) {
                    parser.expected = null;
                    parser.parameter_depth = parser.paren_depth;
                } else if (parser.pending_parameters) {
                    parser.parameter_depth = parser.paren_depth;
                    parser.pending_parameters = false;
                }
                parser.index += 1;
            },
            '[' => {
                if (parser.attribute_depth > 0) parser.attribute_depth += 1;
                parser.index += 1;
            },
            ')' => {
                if (parser.parameter_depth == parser.paren_depth) parser.parameter_depth = null;
                parser.paren_depth -|= 1;
                parser.index += 1;
            },
            ']' => {
                parser.attribute_depth -|= 1;
                parser.index += 1;
            },
            ';', '{' => {
                parser.namespace_mode = false;
                parser.index += 1;
            },
            '$' => try parser.scanVariable(),
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];

        if (parser.attribute_depth > 0) {
            try parser.sink.add(start, parser.index, .attribute);
            return;
        }
        if (parser.namespace_mode) {
            try parser.sink.add(start, parser.index, .namespace);
            return;
        }
        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            parser.pending_parameters = scope == .function;
            parser.expected = null;
            return;
        }
        if (wordIs(word, &.{ "class", "enum", "interface", "trait" })) {
            parser.expected = .type;
        } else if (std.ascii.eqlIgnoreCase(word, "namespace")) {
            parser.namespace_mode = true;
        } else if (wordIs(word, &.{ "function", "fn" })) {
            parser.expected = .function;
        } else if (std.ascii.eqlIgnoreCase(word, "new")) {
            parser.expected = .constructor;
        } else if (previousOperator(parser.source, start, "->") or previousOperator(parser.source, start, "?->")) {
            try parser.sink.add(start, parser.index, if (scanner.nextNonSpace(parser.source, parser.index) == '(') .function else .property);
        } else if (previousOperator(parser.source, start, "::")) {
            try parser.sink.add(start, parser.index, if (scanner.nextNonSpace(parser.source, parser.index) == '(') .function else .property);
        }
    }

    fn scanVariable(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        if (parser.parameter_depth != null and parser.index > start + 1) try parser.sink.add(start, parser.index, .parameter);
    }

    fn skipHeredoc(parser: *StructureParser) void {
        parser.index = heredocEnd(parser.source, parser.index);
    }

    fn startsWith(parser: StructureParser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn skipLine(parser: *StructureParser) void {
        parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
    }

    fn skipBlock(parser: *StructureParser) void {
        parser.index = scanner.blockCommentEnd(parser.source, parser.index, parser.source.len);
    }

    fn skipString(parser: *StructureParser, quote: u8) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
                continue;
            }
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == quote) break;
        }
    }
};

fn phpClose(source: []const u8, start: usize) usize {
    var cursor = start;
    while (cursor < source.len) {
        if (std.mem.startsWith(u8, source[cursor..], "?>")) return cursor;
        if (std.mem.startsWith(u8, source[cursor..], "//") or
            (source[cursor] == '#' and !std.mem.startsWith(u8, source[cursor..], "#[")))
        {
            cursor = scanner.lineEnd(source, cursor, source.len);
        } else if (std.mem.startsWith(u8, source[cursor..], "/*")) {
            cursor = scanner.blockCommentEnd(source, cursor, source.len);
        } else if (std.mem.startsWith(u8, source[cursor..], "<<<")) {
            cursor = heredocEnd(source, cursor);
        } else if (source[cursor] == '\'' or source[cursor] == '"' or source[cursor] == '`') {
            cursor = scanner.quotedEnd(source, cursor, source[cursor], false);
        } else {
            cursor += scanner.validUtf8Length(source[cursor..]);
        }
    }
    return source.len;
}

fn heredocEnd(source: []const u8, start: usize) usize {
    const opener_end = std.mem.indexOfScalarPos(u8, source, start, '\n') orelse return source.len;
    var cursor = start + 3;
    while (cursor < opener_end and (source[cursor] == ' ' or source[cursor] == '\t')) cursor += 1;
    const quote: ?u8 = if (cursor < opener_end and (source[cursor] == '\'' or source[cursor] == '"')) source[cursor] else null;
    if (quote != null) cursor += 1;
    const label_start = cursor;
    while (cursor < opener_end and isIdentifierContinue(source[cursor])) cursor += 1;
    const label = source[label_start..cursor];
    cursor = opener_end + 1;
    if (label.len == 0) return source.len;

    while (cursor < source.len) {
        const line_end = std.mem.indexOfScalarPos(u8, source, cursor, '\n') orelse source.len;
        var content = cursor;
        while (content < line_end and (source[content] == ' ' or source[content] == '\t')) content += 1;
        if (std.mem.startsWith(u8, source[content..line_end], label)) {
            var after = content + label.len;
            if (after < line_end and source[after] == ';') after += 1;
            while (after < line_end and (source[after] == ' ' or source[after] == '\t' or source[after] == '\r')) after += 1;
            if (after == line_end) return line_end;
        }
        cursor = if (line_end < source.len) line_end + 1 else line_end;
    }
    return source.len;
}

fn previousOperator(source: []const u8, before: usize, operator: []const u8) bool {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return cursor >= operator.len and std.mem.eql(u8, source[cursor - operator.len .. cursor], operator);
}

const wordIs = scanner.wordIsIgnoreCase;

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
