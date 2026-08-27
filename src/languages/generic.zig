const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;

pub const BlockComment = struct { open: []const u8, close: []const u8 };
pub const Config = struct {
    line_comments: []const []const u8 = &.{},
    block_comments: []const BlockComment = &.{},
    keywords: []const []const u8 = &.{},
    types: []const []const u8 = &.{},
    constants: []const []const u8 = &.{ "null", "nil", "None" },
    booleans: []const []const u8 = &.{ "true", "false" },
    quotes: []const u8 = "\"'",
    preprocessor: bool = false,
    case_insensitive: bool = false,
    classify_identifiers: bool = true,
    at_scope: Scope = .attribute,
};

pub fn highlight(source: []const u8, sink: *api.CaptureSink, config: Config) api.HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink, .config = config };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    config: Config,
    index: usize = 0,
    line_start: usize = 0,
    after_dot: bool = false,
    fn run(self: *Scanner) api.HighlightError!void {
        while (self.index < self.source.len) {
            if (self.config.preprocessor and self.source[self.index] == '#' and self.onlyIndentBefore()) try self.scanToLineEnd(.macro) else if (self.matchBlock()) |block| try self.scanBlock(block) else if (self.matchText(self.config.line_comments) != null) try self.scanToLineEnd(.comment) else switch (self.source[self.index]) {
                '\n' => {
                    self.index += 1;
                    self.line_start = self.index;
                    self.after_dot = false;
                },
                '0'...'9' => try self.scanNumber(),
                '$' => try self.scanVariable(),
                '@' => try self.scanAttribute(),
                '+', '-', '*', '/', '%', '=', '!', '<', '>', '&', '|', '^', '~', '?', ':' => try self.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', ';' => try self.captureByte(.punctuation, false),
                '.' => try self.captureByte(.punctuation, true),
                else => {
                    if (std.mem.indexOfScalar(u8, self.config.quotes, self.source[self.index]) != null) {
                        try self.scanString(self.source[self.index]);
                    } else if (isIdentifierStart(self.source[self.index])) {
                        try self.scanWord();
                    } else {
                        self.index += 1;
                    }
                },
            }
        }
    }
    fn matchText(self: *const Scanner, values: []const []const u8) ?[]const u8 {
        for (values) |value| if (std.mem.startsWith(u8, self.source[self.index..], value)) return value;
        return null;
    }
    fn matchBlock(self: *const Scanner) ?BlockComment {
        for (self.config.block_comments) |block| if (std.mem.startsWith(u8, self.source[self.index..], block.open)) return block;
        return null;
    }
    fn onlyIndentBefore(self: *const Scanner) bool {
        for (self.source[self.line_start..self.index]) |byte| if (byte != ' ' and byte != '\t') return false;
        return true;
    }
    fn scanToLineEnd(self: *Scanner, scope: Scope) api.HighlightError!void {
        const start = self.index;
        self.index = std.mem.indexOfScalarPos(u8, self.source, start, '\n') orelse self.source.len;
        try self.sink.add(start, self.index, scope);
        if (scope == .comment and (std.mem.startsWith(u8, self.source[start..], "///") or std.mem.startsWith(u8, self.source[start..], "//!"))) try self.sink.add(start, self.index, .documentation);
    }
    fn scanBlock(self: *Scanner, block: BlockComment) api.HighlightError!void {
        const start = self.index;
        self.index += block.open.len;
        const close = std.mem.indexOfPos(u8, self.source, self.index, block.close);
        self.index = if (close) |at| at + block.close.len else self.source.len;
        try self.sink.add(start, self.index, .comment);
        if (std.mem.startsWith(u8, self.source[start..], "/**") or std.mem.startsWith(u8, self.source[start..], "/*!")) try self.sink.add(start, self.index, .documentation);
    }
    fn scanString(self: *Scanner, quote: u8) api.HighlightError!void {
        const start = self.index;
        self.index += 1;
        while (self.index < self.source.len) if (self.source[self.index] == '\\') {
            const at = self.index;
            self.index = escapeEnd(self.source, self.index);
            try self.sink.add(at, self.index, .escape);
        } else {
            self.index += 1;
            if (self.source[self.index - 1] == quote or (quote != '`' and self.source[self.index - 1] == '\n')) break;
        };
        try self.sink.add(start, self.index, .string);
        self.after_dot = false;
    }
    fn scanNumber(self: *Scanner) api.HighlightError!void {
        const start = self.index;
        self.index += 1;
        while (self.index < self.source.len and (std.ascii.isAlphanumeric(self.source[self.index]) or self.source[self.index] == '_' or self.source[self.index] == '.')) self.index += 1;
        try self.sink.add(start, self.index, .number);
        self.after_dot = false;
    }
    fn scanVariable(self: *Scanner) api.HighlightError!void {
        const start = self.index;
        self.index += 1;
        if (self.index < self.source.len and self.source[self.index] == '{') {
            self.index += 1;
            while (self.index < self.source.len and self.source[self.index] != '}') self.index += 1;
            if (self.index < self.source.len) self.index += 1;
        } else while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) self.index += 1;
        const word = self.source[start..self.index];
        const scope: Scope = if (wordEqual(word, "$true", true) or wordEqual(word, "$false", true)) .boolean else if (wordEqual(word, "$null", true)) .constant else .variable;
        try self.sink.add(start, self.index, scope);
    }
    fn scanAttribute(self: *Scanner) api.HighlightError!void {
        const start = self.index;
        self.index += 1;
        if (self.config.at_scope == .variable and self.index < self.source.len and self.source[self.index] == '@') self.index += 1;
        while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) self.index += 1;
        try self.sink.add(start, self.index, self.config.at_scope);
    }
    fn scanOperator(self: *Scanner) api.HighlightError!void {
        const start = self.index;
        self.index += 1;
        while (self.index < self.source.len and std.mem.indexOfScalar(u8, "+-*/%=!<>&|^~?:", self.source[self.index]) != null) self.index += 1;
        try self.sink.add(start, self.index, .operator);
        self.after_dot = false;
    }
    fn captureByte(self: *Scanner, scope: Scope, dot: bool) api.HighlightError!void {
        try self.sink.add(self.index, self.index + 1, scope);
        self.index += 1;
        self.after_dot = dot;
    }
    fn scanWord(self: *Scanner) api.HighlightError!void {
        const start = self.index;
        self.index += 1;
        while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) self.index += 1;
        const word = self.source[start..self.index];
        const scope: ?Scope = if (contains(self.config.keywords, word, self.config.case_insensitive)) .keyword else if (contains(self.config.types, word, self.config.case_insensitive)) .type else if (contains(self.config.booleans, word, self.config.case_insensitive)) .boolean else if (contains(self.config.constants, word, self.config.case_insensitive)) .constant else if (!self.config.classify_identifiers) null else if (self.after_dot) .property else blk: {
            const next = nextByte(self.source, self.index);
            if (next == '(') break :blk .function;
            if (next == '=') break :blk .property;
            if (next == ':') break :blk .label;
            break :blk .variable;
        };
        if (scope) |resolved| {
            try self.sink.add(start, self.index, resolved);
            if (resolved == .type) try self.sink.add(start, self.index, .builtin);
        }
        self.after_dot = false;
    }
};
fn escapeEnd(source: []const u8, start: usize) usize {
    const escaped_start = start + 1;
    if (escaped_start >= source.len) return source.len;
    if (source[escaped_start] >= 0x80) {
        return escaped_start + (validUtf8SequenceLength(source[escaped_start..]) orelse 1);
    }

    var end = escaped_start + 1;
    const digits: usize = switch (source[start + 1]) {
        'x' => 2,
        'u' => 4,
        'U' => 8,
        else => 0,
    };
    var count: usize = 0;
    while (end < source.len and count < digits and std.ascii.isHex(source[end])) : (count += 1) end += 1;
    return end;
}
fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}
fn nextByte(source: []const u8, start: usize) ?u8 {
    var i = start;
    while (i < source.len and std.ascii.isWhitespace(source[i])) i += 1;
    return if (i < source.len) source[i] else null;
}
fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}
fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}
fn wordEqual(a: []const u8, b: []const u8, insensitive: bool) bool {
    return if (insensitive) std.ascii.eqlIgnoreCase(a, b) else std.mem.eql(u8, a, b);
}
fn contains(words: []const []const u8, word: []const u8, insensitive: bool) bool {
    for (words) |candidate| if (wordEqual(word, candidate, insensitive)) return true;
    return false;
}
