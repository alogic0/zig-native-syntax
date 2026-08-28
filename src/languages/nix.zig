const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
const scanner = @import("scanner_support.zig");

const max_interpolation_depth = 32;

pub const backend: api.Backend = .init(.{
    .canonical_name = "nix",
    .display_name = "Nix",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try highlightExpression(source, sink);
}

fn highlightExpression(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try highlightExpressionDepth(source, sink, 0);
}

fn highlightExpressionDepth(source: []const u8, sink: *api.CaptureSink, depth: usize) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .block_comments = &.{.{ .open = "/*", .close = "*/" }},
        .keywords = &.{ "assert", "else", "if", "in", "inherit", "let", "or", "rec", "then", "with" },
        .classify_identifiers = false,
        .strings_stop_at_newline = false,
    });
    var parser: StructureParser = .{ .source = source, .sink = sink, .interpolation_depth = depth };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    let_depth: usize = 0,
    let_brace_depths: [64]usize = @splat(0),
    let_overflow: usize = 0,
    brace_depth: usize = 0,
    inherit_mode: bool = false,
    inherit_expression_depth: usize = 0,
    interpolation_depth: usize,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.skipLine(),
            '/' => {
                if (parser.startsWith("/*")) {
                    parser.skipBlock();
                } else if (isPathStart(parser.source, parser.index)) {
                    try parser.scanPath();
                } else {
                    parser.index += 1;
                }
            },
            '.' => {
                if (parser.startsWith("./") or parser.startsWith("../")) {
                    try parser.scanPath();
                } else {
                    parser.index += 1;
                }
            },
            '<' => {
                if (searchPathEnd(parser.source, parser.index)) |end| {
                    try parser.sink.add(parser.index, end, .string);
                    parser.index = end;
                } else {
                    parser.index += 1;
                }
            },
            '$' => {
                if (parser.startsWith("${")) {
                    try parser.scanDynamicAttribute();
                } else {
                    parser.index += 1;
                }
            },
            '"' => try parser.scanString(),
            '\'' => {
                if (parser.startsWith("''")) {
                    try parser.scanIndentedString();
                } else {
                    parser.index += 1;
                }
            },
            '{' => {
                if (parameterSetEnd(parser.source, parser.index)) |end| {
                    try parser.scanParameterSet(end);
                } else {
                    parser.brace_depth += 1;
                    parser.index += 1;
                }
            },
            '}' => {
                parser.brace_depth -|= 1;
                parser.index += 1;
            },
            '(' => {
                if (parser.inherit_mode) parser.inherit_expression_depth += 1;
                parser.index += 1;
            },
            ')' => {
                parser.inherit_expression_depth -|= 1;
                parser.index += 1;
            },
            ';' => {
                parser.inherit_mode = false;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (std.mem.eql(u8, word, "let")) {
            if (parser.let_depth < parser.let_brace_depths.len) {
                parser.let_brace_depths[parser.let_depth] = parser.brace_depth;
                parser.let_depth += 1;
            } else {
                parser.let_overflow += 1;
            }
        } else if (std.mem.eql(u8, word, "in")) {
            if (parser.let_overflow > 0) parser.let_overflow -= 1 else if (parser.let_depth > 0) parser.let_depth -= 1;
        } else if (std.mem.eql(u8, word, "inherit")) {
            parser.inherit_mode = true;
        } else if (isKeyword(word) or std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false") or std.mem.eql(u8, word, "null")) {
            return;
        } else if (parser.index < parser.source.len and parser.source[parser.index] == '/') {
            try parser.scanPathFrom(start);
        } else if (std.mem.startsWith(u8, parser.source[parser.index..], "://")) {
            parser.index = uriEnd(parser.source, parser.index + 3);
            try parser.sink.add(start, parser.index, .string);
        } else if (previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else if (isBuiltin(word)) {
            try parser.sink.add(start, parser.index, .builtin);
        } else if (parser.inherit_mode) {
            try parser.sink.add(start, parser.index, if (parser.inherit_expression_depth > 0) .variable else .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == ':') {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '=') {
            try parser.sink.add(start, parser.index, if (parser.inLetBindingScope()) .variable else .property);
        } else if (scanner.nextNonSpace(parser.source, parser.index) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanParameterSet(parser: *StructureParser, close: usize) api.HighlightError!void {
        var cursor = parser.index + 1;
        while (cursor < close) {
            if (isIdentifierStart(parser.source[cursor])) {
                const start = cursor;
                cursor += 1;
                while (cursor < close and isIdentifierContinue(parser.source[cursor])) cursor += 1;
                const word = parser.source[start..cursor];
                if (!std.mem.eql(u8, word, "or")) try parser.sink.add(start, cursor, .parameter);
            } else if (parser.source[cursor] == '"') {
                cursor = stringEnd(parser.source, cursor);
            } else cursor += scanner.validUtf8Length(parser.source[cursor..]);
        }
        parser.index = close + 1;
    }

    fn scanString(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        const end = stringEnd(parser.source, parser.index);
        try parser.highlightInterpolations(parser.index + 1, end);
        if (scanner.nextNonSpace(parser.source, end) == '=') try parser.sink.add(start, end, .property);
        parser.index = end;
    }

    fn scanIndentedString(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        const close = indentedStringClose(parser.source, start + 2) orelse parser.source.len;
        const end = if (close < parser.source.len) close + 2 else parser.source.len;
        try parser.sink.add(start, end, .string);
        try parser.highlightIndentedInterpolations(start + 2, close);
        parser.index = end;
    }

    fn scanDynamicAttribute(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        const close = matchingBrace(parser.source, start + 2, parser.source.len) orelse parser.source.len;
        try parser.sink.add(start, start + 2, .special);
        if (start + 2 < close) try parser.highlightEmbeddedExpression(start + 2, close);
        const end = if (close < parser.source.len) close + 1 else close;
        if (close < parser.source.len) try parser.sink.add(close, end, .special);
        if (scanner.nextNonSpace(parser.source, end) == '=' or previousNonSpace(parser.source, start) == '.' or scanner.nextNonSpace(parser.source, end) == '.') {
            try parser.sink.add(start, end, .property);
        }
        parser.index = end;
    }

    fn scanPath(parser: *StructureParser) api.HighlightError!void {
        try parser.scanPathFrom(parser.index);
    }

    fn scanPathFrom(parser: *StructureParser, start: usize) api.HighlightError!void {
        while (parser.index < parser.source.len and !std.ascii.isWhitespace(parser.source[parser.index]) and
            std.mem.indexOfScalar(u8, ";,()[]", parser.source[parser.index]) == null)
        {
            if (parser.source[parser.index] == '$' and parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '{') {
                const close = matchingBrace(parser.source, parser.index + 2, parser.source.len) orelse parser.source.len;
                parser.index = if (close < parser.source.len) close + 1 else close;
                continue;
            }
            if (parser.source[parser.index] == '{' or parser.source[parser.index] == '}') break;
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        try parser.sink.add(start, parser.index, .string);
    }

    fn highlightInterpolations(parser: *StructureParser, start: usize, end: usize) api.HighlightError!void {
        var cursor = start;
        while (cursor < end) {
            const open = std.mem.indexOfPos(u8, parser.source, cursor, "${") orelse break;
            if (open >= end) break;
            const close = matchingBrace(parser.source, open + 2, end) orelse end;
            try parser.sink.add(open, open + 2, .special);
            if (open + 2 < close) try parser.highlightEmbeddedExpression(open + 2, close);
            if (close < end) try parser.sink.add(close, close + 1, .special);
            cursor = if (close < end) close + 1 else end;
        }
    }

    fn highlightIndentedInterpolations(parser: *StructureParser, start: usize, end: usize) api.HighlightError!void {
        var cursor = start;
        while (cursor < end) {
            const open = std.mem.indexOfPos(u8, parser.source, cursor, "${") orelse break;
            if (open >= end) break;
            if (open >= start + 2 and std.mem.eql(u8, parser.source[open - 2 .. open], "''")) {
                cursor = open + 2;
                continue;
            }
            const close = matchingBrace(parser.source, open + 2, end) orelse end;
            try parser.sink.add(open, open + 2, .special);
            if (open + 2 < close) try parser.highlightEmbeddedExpression(open + 2, close);
            if (close < end) try parser.sink.add(close, close + 1, .special);
            cursor = if (close < end) close + 1 else end;
        }
    }

    fn inLetBindingScope(parser: StructureParser) bool {
        return parser.let_depth > 0 and parser.brace_depth == parser.let_brace_depths[parser.let_depth - 1];
    }

    fn highlightEmbeddedExpression(parser: *StructureParser, start: usize, end: usize) api.HighlightError!void {
        try parser.sink.add(start, end, .embedded);
        if (parser.interpolation_depth >= max_interpolation_depth) return;

        const nested_source = parser.source[start..end];
        var nested_sink: api.CaptureSink = .init(parser.sink.allocator, nested_source.len);
        defer nested_sink.deinit();
        try highlightExpressionDepth(nested_source, &nested_sink, parser.interpolation_depth + 1);
        for (nested_sink.captures()) |capture| {
            try parser.sink.add(start + capture.span.start, start + capture.span.end, capture.scope);
        }
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
};

fn parameterSetEnd(source: []const u8, open: usize) ?usize {
    var cursor = open + 1;
    var depth: usize = 1;
    while (cursor < source.len) {
        switch (source[cursor]) {
            '#' => cursor = scanner.lineEnd(source, cursor, source.len),
            '/' => if (startsWithAt(source, cursor, "/*")) {
                cursor = scanner.blockCommentEnd(source, cursor, source.len);
            } else {
                cursor += 1;
            },
            '"' => cursor = stringEnd(source, cursor),
            '\'' => if (startsWithAt(source, cursor, "''")) {
                cursor = indentedStringEnd(source, cursor, source.len);
            } else {
                cursor += 1;
            },
            '{' => {
                depth += 1;
                cursor += 1;
            },
            '}' => {
                depth -= 1;
                if (depth == 0) return if (hasParameterSetSuffix(source, cursor + 1)) cursor else null;
                cursor += 1;
            },
            else => cursor += scanner.validUtf8Length(source[cursor..]),
        }
    }
    return null;
}

fn matchingBrace(source: []const u8, start: usize, limit: usize) ?usize {
    var cursor = start;
    var depth: usize = 1;
    while (cursor < limit) switch (source[cursor]) {
        '#' => cursor = scanner.lineEnd(source, cursor, limit),
        '/' => if (startsWithAt(source, cursor, "/*")) {
            cursor = scanner.blockCommentEnd(source, cursor, limit);
        } else {
            cursor += 1;
        },
        '"' => cursor = @min(stringEnd(source, cursor), limit),
        '\'' => if (startsWithAt(source, cursor, "''")) {
            cursor = indentedStringEnd(source, cursor, limit);
        } else {
            cursor += 1;
        },
        '{' => {
            depth += 1;
            cursor += 1;
        },
        '}' => {
            depth -= 1;
            if (depth == 0) return cursor;
            cursor += 1;
        },
        else => cursor += scanner.validUtf8Length(source[cursor..]),
    };
    return null;
}

fn isPathStart(source: []const u8, start: usize) bool {
    if (start + 1 >= source.len or source[start] != '/') return false;
    if (source[start + 1] == '/' or source[start + 1] == '*') return false;
    const previous = previousNonSpace(source, start) orelse return true;
    return std.mem.indexOfScalar(u8, "=([{,:;", previous) != null;
}

fn searchPathEnd(source: []const u8, start: usize) ?usize {
    var cursor = start + 1;
    if (cursor >= source.len) return null;
    while (cursor < source.len) : (cursor += scanner.validUtf8Length(source[cursor..])) {
        if (source[cursor] == '>') return if (cursor > start + 1) cursor + 1 else null;
        if (std.ascii.isWhitespace(source[cursor]) or source[cursor] == '<') return null;
    }
    return null;
}

fn uriEnd(source: []const u8, start: usize) usize {
    var cursor = start;
    while (cursor < source.len and !std.ascii.isWhitespace(source[cursor]) and
        std.mem.indexOfScalar(u8, ";,(){}[]", source[cursor]) == null)
    {
        cursor += scanner.validUtf8Length(source[cursor..]);
    }
    return cursor;
}

fn indentedStringClose(source: []const u8, start: usize) ?usize {
    var cursor = start;
    while (cursor + 1 < source.len) {
        if (!startsWithAt(source, cursor, "''")) {
            cursor += scanner.validUtf8Length(source[cursor..]);
            continue;
        }
        if (cursor + 2 < source.len and source[cursor + 2] == '\'') {
            cursor += 3;
            continue;
        }
        if (cursor + 2 < source.len and source[cursor + 2] == '$') {
            cursor += 3;
            continue;
        }
        if (cursor + 2 < source.len and source[cursor + 2] == '\\') {
            cursor += @min(@as(usize, 4), source.len - cursor);
            continue;
        }
        return cursor;
    }
    return null;
}

fn indentedStringEnd(source: []const u8, start: usize, limit: usize) usize {
    const close = indentedStringClose(source, start + 2) orelse return limit;
    return @min(close + 2, limit);
}

fn hasParameterSetSuffix(source: []const u8, after: usize) bool {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    if (cursor < source.len and source[cursor] == '@') {
        cursor += 1;
        while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
        if (cursor >= source.len or !isIdentifierStart(source[cursor])) return false;
        cursor += 1;
        while (cursor < source.len and isIdentifierContinue(source[cursor])) cursor += 1;
        while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    }
    return cursor < source.len and source[cursor] == ':';
}

fn startsWithAt(source: []const u8, start: usize, text: []const u8) bool {
    return start <= source.len and std.mem.startsWith(u8, source[start..], text);
}

fn stringEnd(source: []const u8, start: usize) usize {
    var cursor = start + 1;
    while (cursor < source.len) {
        if (source[cursor] == '\\') {
            cursor += @min(@as(usize, 2), source.len - cursor);
            continue;
        }
        cursor += 1;
        if (source[cursor - 1] == '"') break;
    }
    return cursor;
}

fn previousNonSpace(source: []const u8, before: usize) ?u8 {
    var cursor = before;
    while (cursor > 0 and std.ascii.isWhitespace(source[cursor - 1])) cursor -= 1;
    return if (cursor > 0) source[cursor - 1] else null;
}

fn isBuiltin(word: []const u8) bool {
    const builtins = [_][]const u8{ "abort", "baseNameOf", "builtins", "derivation", "dirOf", "fetchTarball", "import", "map", "removeAttrs", "throw", "toString" };
    for (&builtins) |builtin| {
        if (std.mem.eql(u8, word, builtin)) return true;
    }
    return false;
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{ "assert", "else", "if", "in", "inherit", "let", "or", "rec", "then", "with" };
    for (&keywords) |keyword| if (std.mem.eql(u8, word, keyword)) return true;
    return false;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-' or byte == '\'';
}
