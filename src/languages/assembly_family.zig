const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const scanner_support = @import("scanner_support.zig");

pub const Dialect = enum { gas, nasm };

pub fn highlight(source: []const u8, sink: *api.CaptureSink, dialect: Dialect) api.HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink, .dialect = dialect };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    dialect: Dialect,
    index: usize = 0,
    macro_name_pending: bool = false,
    label_operand_pending: bool = false,
    expect_opcode: bool = true,

    fn run(scanner: *Scanner) api.HighlightError!void {
        while (scanner.index < scanner.source.len) switch (scanner.source[scanner.index]) {
            ' ', '\t', '\r' => scanner.index += 1,
            '\n' => {
                scanner.macro_name_pending = false;
                scanner.label_operand_pending = false;
                scanner.expect_opcode = true;
                scanner.index += 1;
            },
            '#' => if (scanner.dialect == .gas and !isImmediate(scanner.source, scanner.index))
                try scanner.scanComment()
            else
                try scanner.scanOperator(),
            ';' => if (scanner.dialect == .nasm)
                try scanner.scanComment()
            else
                try scanner.captureByte(.punctuation),
            '\'', '"' => try scanner.scanString(scanner.source[scanner.index]),
            '0'...'9' => try scanner.scanNumber(),
            'a'...'z', 'A'...'Z', '_', '.', '%', '$', '@' => try scanner.scanWord(),
            '+', '-', '*', '/', '=', '&', '|', '^', '~', '<', '>', '!' => try scanner.scanOperator(),
            '(', ')', '[', ']', '{', '}', ',', ':' => try scanner.captureByte(.punctuation),
            else => scanner.index += scanner_support.validUtf8Length(scanner.source[scanner.index..]),
        };
    }

    fn scanComment(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index = scanner_support.lineEnd(scanner.source, scanner.index, scanner.source.len);
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanString(scanner: *Scanner, quote: u8) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len) {
            if (scanner.source[scanner.index] == '\\') {
                const escape = scanner.index;
                scanner.index = scanner_support.escapeEnd(scanner.source, scanner.index);
                try scanner.sink.add(escape, scanner.index, .escape);
                continue;
            }
            const byte = scanner.source[scanner.index];
            scanner.index += scanner_support.validUtf8Length(scanner.source[scanner.index..]);
            if (byte == quote or byte == '\n') break;
        }
        try scanner.sink.add(start, scanner.index, .string);
    }

    fn scanNumber(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isNumberByte(scanner.source[scanner.index])) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanWord(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isWordByte(scanner.source[scanner.index])) scanner.index += 1;
        const word = scanner.source[start..scanner.index];

        if (word.len > 1 and word[0] == '$' and std.ascii.isDigit(word[1])) {
            try scanner.sink.add(start, scanner.index, .number);
            return;
        }
        if (nextNonSpace(scanner.source, scanner.index) == ':') {
            try scanner.sink.add(start, scanner.index, .label);
            scanner.label_operand_pending = false;
            return;
        }
        if (scanner.macro_name_pending) {
            try scanner.sink.add(start, scanner.index, .macro);
            scanner.macro_name_pending = false;
            return;
        }
        if (isMacroDirective(word, scanner.dialect)) {
            try scanner.sink.add(start, scanner.index, .macro);
            scanner.macro_name_pending = declaresMacro(word);
            scanner.expect_opcode = false;
            return;
        }
        if (scanner.expect_opcode and takesSymbolOperand(word)) {
            try scanner.sink.add(start, scanner.index, .keyword);
            scanner.label_operand_pending = true;
            scanner.expect_opcode = false;
            return;
        }
        if (scanner.expect_opcode) {
            try scanner.sink.add(start, scanner.index, .keyword);
            scanner.label_operand_pending = isControlTransfer(word);
            scanner.expect_opcode = isInstructionPrefix(word);
            return;
        }
        if (isRegister(word)) {
            try scanner.sink.add(start, scanner.index, .type);
            return;
        }
        if (isSizeName(word)) {
            try scanner.sink.add(start, scanner.index, .type);
            return;
        }
        if (scanner.label_operand_pending) {
            try scanner.sink.add(start, scanner.index, .label);
            scanner.label_operand_pending = false;
        }
    }

    fn scanOperator(scanner: *Scanner) api.HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isOperator(scanner.source[scanner.index])) scanner.index += 1;
        try scanner.sink.add(start, scanner.index, .operator);
    }

    fn captureByte(scanner: *Scanner, scope: Scope) api.HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }
};

fn isImmediate(source: []const u8, index: usize) bool {
    if (index + 1 >= source.len) return false;
    return std.ascii.isDigit(source[index + 1]) or source[index + 1] == '-' or source[index + 1] == '+';
}

fn isNumberByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '.';
}

fn isWordByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or std.mem.indexOfScalar(u8, "_.$%@?", byte) != null;
}

fn isOperator(byte: u8) bool {
    return std.mem.indexOfScalar(u8, "#+-*/=&|^~<>!", byte) != null;
}

fn nextNonSpace(source: []const u8, after: usize) ?u8 {
    var cursor = after;
    while (cursor < source.len and (source[cursor] == ' ' or source[cursor] == '\t' or source[cursor] == '\r')) cursor += 1;
    return if (cursor < source.len) source[cursor] else null;
}

fn isMacroDirective(word: []const u8, dialect: Dialect) bool {
    return if (dialect == .gas)
        wordIs(word, &.{ ".altmacro", ".endm", ".endr", ".irp", ".irpc", ".macro", ".rept" })
    else
        wordIs(word, &.{ "%assign", "%define", "%elif", "%else", "%endif", "%endmacro", "%if", "%ifdef", "%ifndef", "%include", "%macro", "%rep", "%endrep", "%undef" });
}

fn declaresMacro(word: []const u8) bool {
    return wordIs(word, &.{ ".macro", "%assign", "%define", "%macro" });
}

fn takesSymbolOperand(word: []const u8) bool {
    return wordIs(word, &.{ ".extern", ".globl", ".global", "common", "extern", "global" });
}

fn isControlTransfer(word: []const u8) bool {
    return std.ascii.toLower(word[0]) == 'j' or wordIs(word, &.{ "b", "beq", "bge", "bgt", "bl", "ble", "blt", "bne", "bx", "call", "cbnz", "cbz" });
}

fn isInstructionPrefix(word: []const u8) bool {
    return wordIs(word, &.{ "lock", "rep", "repe", "repne", "repnz", "repz" });
}

fn isRegister(word: []const u8) bool {
    const bare = if (word.len > 1 and word[0] == '%') word[1..] else word;
    if (wordIs(bare, &.{
        "ah",  "al",  "ax",  "bh",  "bl",  "bp",  "bpl", "bx",  "ch",  "cl", "cx",  "dh",  "di",  "dil", "dl",  "dx",
        "eax", "ebp", "ebx", "ecx", "edi", "edx", "esi", "esp", "ip",  "pc", "rax", "rbp", "rbx", "rcx", "rdi", "rdx",
        "rip", "rsi", "rsp", "si",  "sil", "sp",  "spl", "xzr", "wzr", "lr",
    })) return true;
    return isNumberedRegister(bare);
}

fn isNumberedRegister(word: []const u8) bool {
    if (word.len < 2) return false;
    var prefix_len: usize = 1;
    var maximum: u8 = 31;
    const first = std.ascii.toLower(word[0]);
    if (word.len > 3 and (first == 'x' or first == 'y' or first == 'z') and
        std.ascii.toLower(word[1]) == 'm' and std.ascii.toLower(word[2]) == 'm')
    {
        prefix_len = 3;
    } else if (word.len > 2 and first == 's' and std.ascii.toLower(word[1]) == 't') {
        prefix_len = 2;
        maximum = 7;
    } else if (std.mem.indexOfScalar(u8, "rwxv", first) == null) {
        return false;
    }
    const digits = word[prefix_len..];
    if (digits.len > 2 or !std.ascii.isDigit(digits[0])) return false;
    var number = digits[0] - '0';
    if (digits.len == 2) {
        if (!std.ascii.isDigit(digits[1])) return false;
        number = number * 10 + digits[1] - '0';
    }
    return number <= maximum;
}

fn isSizeName(word: []const u8) bool {
    return wordIs(word, &.{ "byte", "dword", "oword", "ptr", "qword", "tword", "word", "xmmword", "ymmword", "zmmword" });
}

fn wordIs(word: []const u8, candidates: []const []const u8) bool {
    return scanner_support.wordIsIgnoreCase(word, candidates);
}
