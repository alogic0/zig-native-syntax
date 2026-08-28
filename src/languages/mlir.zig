const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const nextNonSpace = @import("scanner_support.zig").nextNonSpace;
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;

pub const backend: api.Backend = .init(.{
    .canonical_name = "mlir",
    .display_name = "MLIR",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,

    fn run(scanner: *Scanner) api.HighlightError!void {
        while (scanner.index < scanner.source.len) {
            if (scanner.startsWith("//")) {
                try scanner.scanComment();
            } else switch (scanner.source[scanner.index]) {
                '"' => try scanner.scanString(),
                '%', '@', '^', '!', '#', '$' => try scanner.scanSigil(),
                '0'...'9' => try scanner.scanNumber(),
                'a'...'z', 'A'...'Z', '_' => try scanner.scanWord(),
                '-', '+', '*', '/', '=', '<', '>', ':' => try scanner.scanOperator(),
                '(', ')', '[', ']', '{', '}', ',', '.' => try scanner.captureByte(.punctuation),
                else => scanner.index += validUtf8Length(scanner.source[scanner.index..]),
            }
        }
    }

    fn startsWith(scanner: Scanner, text: []const u8) bool {
        return std.mem.startsWith(u8, scanner.source[scanner.index..], text);
    }

    fn scanComment(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, scanner.index, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanString(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            if (scanner.source[scanner.index] == '\\') {
                const escape = scanner.index;
                scanner.index += 1;
                if (scanner.index < scanner.source.len) scanner.index += validUtf8Length(scanner.source[scanner.index..]);
                try scanner.sink.add(escape, scanner.index, .escape);
                continue;
            }
            const byte = scanner.source[scanner.index];
            scanner.index += 1;
            if (byte == '"' or byte == '\n') break;
        }
        try scanner.sink.add(start, scanner.index, .string);
    }

    fn scanSigil(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        const sigil = scanner.source[scanner.index];
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isSigilContinue(scanner.source[scanner.index])) scanner.index += 1;
        const scope: Scope = switch (sigil) {
            '%' => .variable,
            '@' => .function,
            '^' => .label,
            '!' => .type,
            '#' => .attribute,
            '$' => .parameter,
            else => unreachable,
        };
        try scanner.sink.add(start, scanner.index, scope);
    }

    fn scanNumber(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and (std.ascii.isAlphanumeric(scanner.source[scanner.index]) or scanner.source[scanner.index] == '.' or scanner.source[scanner.index] == '_')) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanWord(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and (std.ascii.isAlphanumeric(scanner.source[scanner.index]) or scanner.source[scanner.index] == '_' or scanner.source[scanner.index] == '.')) scanner.index += 1;
        const word = scanner.source[start..scanner.index];
        if (isKeyword(word)) {
            try scanner.sink.add(start, scanner.index, .keyword);
        } else if (isBuiltinType(word)) {
            try scanner.sink.add(start, scanner.index, .type);
            try scanner.sink.add(start, scanner.index, .builtin);
        } else if (isBoolean(word)) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (std.mem.indexOfScalar(u8, word, '.') != null) {
            try scanner.sink.add(start, scanner.index, .function);
        } else if (nextNonSpace(scanner.source, scanner.index) == '=') {
            try scanner.sink.add(start, scanner.index, .property);
        }
    }

    fn scanOperator(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and std.mem.indexOfScalar(u8, "-+*/=<>:", scanner.source[scanner.index]) != null) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn captureByte(scanner: *Scanner, scope: Scope) api.HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }
};

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "affine_map", "attributes", "builtin.module", "call", "callee", "else", "func.func", "ins", "loc", "outs", "return", "sym_name", "then", "to", "type", "unit" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn isBuiltinType(word: []const u8) bool {
    if (word.len > 1 and (word[0] == 'i' or word[0] == 'f') and allDigits(word[1..])) return true;
    const words = [_][]const u8{ "bf16", "complex", "index", "memref", "none", "tensor", "tuple", "vector" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn allDigits(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return false;
    return true;
}

fn isBoolean(word: []const u8) bool {
    return std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false");
}

fn isSigilContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.' or byte == '-' or byte == '$';
}
