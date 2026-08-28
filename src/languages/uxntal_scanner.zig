const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var index: usize = 0;
    while (index < source.len) {
        const byte = source[index];
        if (std.ascii.isWhitespace(byte)) {
            index += 1;
        } else if (byte == '(') {
            const end = commentEnd(source, index);
            try sink.add(index, end, .comment);
            index = end;
        } else if (byte == '"') {
            const end = tokenEnd(source, index + 1);
            try sink.add(index, end, .string);
            index = end;
        } else if (byte == '%' and hasTokenByte(source, index + 1)) {
            const end = tokenEnd(source, index + 1);
            try sink.add(index, end, .macro);
            index = end;
        } else if (isLabelRune(byte) and hasTokenByte(source, index + 1)) {
            const end = tokenEnd(source, index + 1);
            try sink.add(index, end, .label);
            index = end;
        } else if (isNumberRune(byte)) {
            const end = tokenEnd(source, index + 1);
            if (end > index + 1 and isHexNumber(source[index + 1 .. end])) {
                try sink.add(index, end, .number);
                index = end;
            } else {
                try sink.add(index, index + 1, .operator);
                index += 1;
            }
        } else if (byte == '{' or byte == '}' or byte == '[' or byte == ']') {
            try sink.add(index, index + 1, .punctuation);
            index += 1;
        } else if (isStandaloneRune(byte)) {
            try sink.add(index, index + 1, .operator);
            index += 1;
        } else if (hasTokenByte(source, index)) {
            const end = tokenEnd(source, index);
            const token = source[index..end];
            if (isOpcode(token)) {
                try sink.add(index, end, .keyword);
            } else if (isHexNumber(token)) {
                try sink.add(index, end, .number);
            }
            index = end;
        } else {
            index += scanner.validUtf8Length(source[index..]);
        }
    }
}

fn commentEnd(source: []const u8, start: usize) usize {
    var index = start + 1;
    var depth: usize = 1;
    while (index < source.len) {
        if (source[index] == '(') {
            depth += 1;
            index += 1;
        } else if (source[index] == ')') {
            depth -= 1;
            index += 1;
            if (depth == 0) return index;
        } else {
            index += scanner.validUtf8Length(source[index..]);
        }
    }
    return source.len;
}

fn tokenEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and hasTokenByte(source, index)) {
        index += scanner.validUtf8Length(source[index..]);
    }
    return index;
}

fn hasTokenByte(source: []const u8, index: usize) bool {
    if (index >= source.len) return false;
    return !std.ascii.isWhitespace(source[index]) and !isDelimiter(source[index]);
}

fn isDelimiter(byte: u8) bool {
    return byte == '(' or byte == ')' or byte == '{' or byte == '}' or byte == '[' or byte == ']';
}

fn isLabelRune(byte: u8) bool {
    return switch (byte) {
        '@', '&', ',', '_', '.', '-', ';', '=', '!', '?', '/' => true,
        else => false,
    };
}

fn isNumberRune(byte: u8) bool {
    return byte == '#' or byte == '|' or byte == '$';
}

fn isStandaloneRune(byte: u8) bool {
    return isLabelRune(byte) or isNumberRune(byte) or byte == '%';
}

fn isHexNumber(token: []const u8) bool {
    if (token.len == 0 or token.len > 4) return false;
    for (token) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn isOpcode(token: []const u8) bool {
    if (token.len < 3) return false;
    if (!scanner.wordIs(token[0..3], &.{ "ADD", "AND", "BRK", "DEI", "DEO", "DIV", "DUP", "EOR", "EQU", "GTH", "INC", "JCI", "JCN", "JMI", "JMP", "JSI", "JSR", "LDA", "LDR", "LDZ", "LIT", "LTH", "MUL", "NEQ", "NIP", "ORA", "OVR", "POP", "ROT", "SFT", "STA", "STH", "STR", "STZ", "SUB", "SWP" })) return false;
    for (token[3..]) |suffix| if (suffix != '2' and suffix != 'k' and suffix != 'r') return false;
    return true;
}

test "Uxntal opcode modes remain part of the opcode" {
    try std.testing.expect(isOpcode("INC2r"));
    try std.testing.expect(isOpcode("LIT2kr"));
    try std.testing.expect(!isOpcode("INCx"));
}

test "Uxntal comments nest and recover at end of input" {
    try std.testing.expectEqual(@as(usize, 19), commentEnd("( outer ( inner ) )", 0));
    try std.testing.expectEqual(@as(usize, 8), commentEnd("( broken", 0));
}
