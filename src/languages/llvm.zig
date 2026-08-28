const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const nextNonSpace = @import("scanner_support.zig").nextNonSpace;
const validUtf8Length = @import("scanner_support.zig").validUtf8Length;

pub const backend: api.Backend = .init(.{ .canonical_name = "llvm", .display_name = "LLVM IR", .kind = .lexical, .support_level = .verified_lexical }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,

    fn run(scanner: *Scanner) api.HighlightError!void {
        while (scanner.index < scanner.source.len) switch (scanner.source[scanner.index]) {
            ';' => try scanner.scanComment(),
            '"' => try scanner.scanString(scanner.index),
            'c' => if (scanner.index + 1 < scanner.source.len and scanner.source[scanner.index + 1] == '"') try scanner.scanString(scanner.index) else try scanner.scanWord(),
            '%', '@', '!' => try scanner.scanSigil(),
            '0'...'9' => try scanner.scanNumber(),
            'a'...'b', 'd'...'z', 'A'...'Z', '_' => try scanner.scanWord(),
            '=', '+', '-', '*', '/', '<', '>' => try scanner.scanOperator(),
            '(', ')', '[', ']', '{', '}', ',', ':' => try scanner.captureByte(.punctuation),
            else => scanner.index += validUtf8Length(scanner.source[scanner.index..]),
        };
    }

    fn scanComment(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, scanner.index, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanString(scanner: *Scanner, start: usize) api.HighlightError!void {
        if (scanner.source[scanner.index] == 'c') scanner.index += 1;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            if (scanner.source[scanner.index] == '\\') {
                const escape = scanner.index;
                scanner.index += 1;
                while (scanner.index < scanner.source.len and scanner.index - escape <= 2 and std.ascii.isHex(scanner.source[scanner.index])) scanner.index += 1;
                if (scanner.index == escape + 1 and scanner.index < scanner.source.len) scanner.index += validUtf8Length(scanner.source[scanner.index..]);
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
        if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '"') {
            scanner.index += 1;
            while (scanner.index < scanner.source.len and scanner.source[scanner.index] != '"' and scanner.source[scanner.index] != '\n') scanner.index += validUtf8Length(scanner.source[scanner.index..]);
            if (scanner.index < scanner.source.len and scanner.source[scanner.index] == '"') scanner.index += 1;
        } else while (scanner.index < scanner.source.len and isNameContinue(scanner.source[scanner.index])) scanner.index += 1;
        const scope: Scope = switch (sigil) {
            '%' => .variable,
            '@' => if (nextNonSpace(scanner.source, scanner.index) == '(') .function else .constant,
            '!' => .attribute,
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
        } else if (isType(word)) {
            try scanner.sink.add(start, scanner.index, .type);
        } else if (isBoolean(word)) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (isConstant(word)) {
            try scanner.sink.add(start, scanner.index, .constant);
        } else if (nextNonSpace(scanner.source, scanner.index) == ':') {
            try scanner.sink.add(start, scanner.index, .label);
        }
    }

    fn scanOperator(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and std.mem.indexOfScalar(u8, "=+-*/<>", scanner.source[scanner.index]) != null) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn captureByte(scanner: *Scanner, scope: Scope) api.HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }
};

fn isKeyword(word: []const u8) bool {
    const words = [_][]const u8{ "add", "alloca", "and", "ashr", "bitcast", "br", "call", "declare", "define", "extractvalue", "fadd", "fcmp", "fdiv", "fmul", "fpext", "fptosi", "fsub", "getelementptr", "icmp", "indirectbr", "insertvalue", "invoke", "landingpad", "load", "lshr", "mul", "or", "phi", "ret", "resume", "select", "sext", "shl", "sdiv", "sitofp", "store", "sub", "switch", "trunc", "udiv", "uitofp", "unreachable", "va_arg", "xor", "zext" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn isType(word: []const u8) bool {
    if (word.len > 1 and word[0] == 'i' and allDigits(word[1..])) return true;
    const words = [_][]const u8{ "bfloat", "double", "float", "fp128", "half", "label", "metadata", "ptr", "token", "void", "x86_fp80" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn allDigits(text: []const u8) bool {
    for (text) |byte| if (!std.ascii.isDigit(byte)) return false;
    return text.len != 0;
}

fn isBoolean(word: []const u8) bool {
    return std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false");
}

fn isConstant(word: []const u8) bool {
    const words = [_][]const u8{ "none", "null", "poison", "undef", "zeroinitializer" };
    for (words) |candidate| if (std.mem.eql(u8, candidate, word)) return true;
    return false;
}

fn isNameContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.' or byte == '-';
}
