const std = @import("std");
const api = @import("../backend.zig");
const composition = @import("../composition.zig");
const g = @import("generic.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "nix",
    .display_name = "Nix",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

const expression_backend: api.Backend = .init(.{
    .canonical_name = "nix-expression",
    .display_name = "Nix expression",
    .kind = .parser_backed,
}, highlightExpression);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try highlightExpression(source, sink);
}

fn highlightExpression(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .block_comments = &.{.{ .open = "/*", .close = "*/" }},
        .keywords = &.{ "assert", "else", "if", "in", "inherit", "let", "or", "rec", "then", "with" },
        .classify_identifiers = false,
        .strings_stop_at_newline = false,
    });
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    let_depth: usize = 0,
    inherit_mode: bool = false,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            '#' => parser.skipLine(),
            '/' => {
                if (parser.startsWith("/*")) parser.skipBlock() else parser.index += 1;
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
                    parser.index += 1;
                }
            },
            ';' => {
                parser.inherit_mode = false;
                parser.index += 1;
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isIdentifierContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];
        if (std.mem.eql(u8, word, "let")) {
            parser.let_depth += 1;
        } else if (std.mem.eql(u8, word, "in") and parser.let_depth > 0) {
            parser.let_depth -= 1;
        } else if (std.mem.eql(u8, word, "inherit")) {
            parser.inherit_mode = true;
        } else if (isKeyword(word) or std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false") or std.mem.eql(u8, word, "null")) {
            return;
        } else if (previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else if (isBuiltin(word)) {
            try parser.sink.add(start, parser.index, .builtin);
        } else if (parser.inherit_mode) {
            try parser.sink.add(start, parser.index, .property);
        } else if (nextNonSpace(parser.source, parser.index) == ':') {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (nextNonSpace(parser.source, parser.index) == '=') {
            try parser.sink.add(start, parser.index, if (parser.let_depth > 0) .variable else .property);
        } else if (nextNonSpace(parser.source, parser.index) == '.') {
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
            } else cursor += validUtf8Length(parser.source[cursor..]);
        }
        parser.index = close + 1;
    }

    fn scanString(parser: *StructureParser) api.HighlightError!void {
        const end = stringEnd(parser.source, parser.index);
        try parser.highlightInterpolations(parser.index + 1, end);
        parser.index = end;
    }

    fn scanIndentedString(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        const close = std.mem.indexOfPos(u8, parser.source, start + 2, "''") orelse parser.source.len;
        const end = if (close < parser.source.len) close + 2 else parser.source.len;
        try parser.sink.add(start, end, .string);
        try parser.highlightInterpolations(start + 2, close);
        parser.index = end;
    }

    fn highlightInterpolations(parser: *StructureParser, start: usize, end: usize) api.HighlightError!void {
        var cursor = start;
        while (cursor < end) {
            const open = std.mem.indexOfPos(u8, parser.source, cursor, "${") orelse break;
            if (open >= end) break;
            const close = matchingBrace(parser.source, open + 2, end) orelse end;
            try parser.sink.add(open, open + 2, .special);
            if (open + 2 < close) try composition.highlightEmbedded(parser.source, .{ .start = open + 2, .end = close }, expression_backend, parser.sink);
            if (close < end) try parser.sink.add(close, close + 1, .special);
            cursor = if (close < end) close + 1 else end;
        }
    }

    fn startsWith(parser: StructureParser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn skipLine(parser: *StructureParser) void {
        parser.index = std.mem.indexOfScalarPos(u8, parser.source, parser.index, '\n') orelse parser.source.len;
    }

    fn skipBlock(parser: *StructureParser) void {
        parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |close| close + 2 else parser.source.len;
    }
};

fn parameterSetEnd(source: []const u8, open: usize) ?usize {
    var cursor = open + 1;
    var depth: usize = 1;
    while (cursor < source.len) {
        switch (source[cursor]) {
            '"' => cursor = stringEnd(source, cursor),
            '{' => {
                depth += 1;
                cursor += 1;
            },
            '}' => {
                depth -= 1;
                if (depth == 0) return if (nextNonSpace(source, cursor + 1) == ':') cursor else null;
                cursor += 1;
            },
            else => cursor += validUtf8Length(source[cursor..]),
        }
    }
    return null;
}

fn matchingBrace(source: []const u8, start: usize, limit: usize) ?usize {
    var cursor = start;
    var depth: usize = 1;
    while (cursor < limit) switch (source[cursor]) {
        '"' => cursor = stringEnd(source, cursor),
        '{' => {
            depth += 1;
            cursor += 1;
        },
        '}' => {
            depth -= 1;
            if (depth == 0) return cursor;
            cursor += 1;
        },
        else => cursor += validUtf8Length(source[cursor..]),
    };
    return null;
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

fn nextNonSpace(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and std.ascii.isWhitespace(source[cursor])) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
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

fn validUtf8Length(source: []const u8) usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return 1;
    if (len > source.len) return 1;
    _ = std.unicode.utf8Decode(source[0..len]) catch return 1;
    return len;
}
