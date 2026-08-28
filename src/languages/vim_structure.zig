const std = @import("std");
const api = @import("../backend.zig");
const scanner = @import("scanner_support.zig");

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var line_start: usize = 0;
    while (line_start < source.len) {
        const line_end = scanner.lineEnd(source, line_start, source.len);
        try scanLine(source, line_start, line_end, sink);
        line_start = if (line_end < source.len) line_end + 1 else line_end;
    }
}

fn scanLine(source: []const u8, line_start: usize, line_end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var index = skipSpace(source, line_start, line_end);
    if (index >= line_end) return;
    if (source[index] == '#') {
        try sink.add(index, line_end, .comment);
        return;
    }
    if (source[index] == ':') index = skipSpace(source, index + 1, line_end);
    if (index >= line_end or !scanner.isAsciiIdentifierStart(source[index])) return;

    const command_start = index;
    index = scanner.identifierEnd(source, index, .ascii);
    const command = source[command_start..index];
    if (index < line_end and source[index] == '!') index += 1;

    if (std.mem.eql(u8, command, "function") or std.mem.eql(u8, command, "def")) {
        index = skipSpace(source, index, line_end);
        const name_end = vimNameEnd(source, index, line_end);
        if (name_end > index) try sink.add(index, name_end, .function);
        try scanParameters(source, name_end, line_end, sink);
        return;
    }

    if (isBindingCommand(command) or std.mem.eql(u8, command, "for")) {
        index = skipSpace(source, index, line_end);
        const name_end = vimNameEnd(source, index, line_end);
        if (name_end > index) {
            try sink.add(index, name_end, .variable);
            index = name_end;
        }
    } else if (std.mem.eql(u8, command, "call")) {
        index = skipSpace(source, index, line_end);
        const name_end = dottedNameEnd(source, index, line_end);
        if (name_end > index) {
            try sink.add(index, name_end, .function);
            index = name_end;
        }
    } else if (std.mem.eql(u8, command, "command")) {
        index = commandNameStart(source, index, line_end);
        const name_end = vimNameEnd(source, index, line_end);
        if (name_end > index) {
            try sink.add(index, name_end, .macro);
            index = name_end;
        }
    } else if (std.mem.eql(u8, command, "import")) {
        try scanImportAlias(source, index, line_end, sink);
    }

    try scanExpressions(source, index, line_end, sink);
}

fn scanImportAlias(source: []const u8, start: usize, line_end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var index = start;
    while (index < line_end) {
        if (source[index] == '\'') {
            index = singleQuotedEnd(source, index, line_end);
            continue;
        }
        if (!scanner.isAsciiIdentifierStart(source[index])) {
            index += scanner.validUtf8Length(source[index..]);
            continue;
        }
        const word_start = index;
        index = scanner.identifierEnd(source, index, .ascii);
        if (!std.mem.eql(u8, source[word_start..index], "as")) continue;
        index = skipSpace(source, index, line_end);
        const alias_end = vimNameEnd(source, index, line_end);
        if (alias_end > index) try sink.add(index, alias_end, .namespace);
        return;
    }
}

fn scanParameters(source: []const u8, after_name: usize, line_end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var index = skipSpace(source, after_name, line_end);
    if (index >= line_end or source[index] != '(') return;
    index += 1;
    var expect_parameter = true;
    while (index < line_end) {
        if (source[index] == '\'') {
            index = singleQuotedEnd(source, index, line_end);
        } else if (source[index] == '"') {
            return;
        } else if (source[index] == ')') {
            return;
        } else if (source[index] == ',') {
            expect_parameter = true;
            index += 1;
        } else if (expect_parameter and scanner.isAsciiIdentifierStart(source[index])) {
            const end = scanner.identifierEnd(source, index, .ascii);
            try sink.add(index, end, .parameter);
            index = end;
            expect_parameter = false;
        } else {
            index += scanner.validUtf8Length(source[index..]);
        }
    }
}

fn scanExpressions(source: []const u8, start: usize, line_end: usize, sink: *api.CaptureSink) api.HighlightError!void {
    var index = start;
    while (index < line_end) {
        if (source[index] == '\'') {
            index = singleQuotedEnd(source, index, line_end);
            continue;
        }
        if (source[index] == '"') return;
        if (!isVimNameStart(source, index, line_end)) {
            index += scanner.validUtf8Length(source[index..]);
            continue;
        }

        const name_start = index;
        index = vimNameEnd(source, index, line_end);
        if (index == name_start) {
            index += 1;
            continue;
        }
        const name = source[name_start..index];
        if (isKeyword(name) or isType(name) or isConstant(name)) continue;

        const next = nextCodeByte(source, index, line_end);
        const previous = previousCodeByte(source, name_start, start);
        if (previous == '.') {
            try sink.add(name_start, index, if (next == '(') .function else .property);
        } else if (next == '.') {
            try sink.add(name_start, index, .namespace);
        } else if (next == '(') {
            try sink.add(name_start, index, .function);
        } else if (hasScopePrefix(name) or name[0] == '&' or name[0] == '$' or name[0] == '@') {
            try sink.add(name_start, index, .variable);
        }
    }
}

fn vimNameEnd(source: []const u8, start: usize, limit: usize) usize {
    if (start >= limit) return start;
    var index = start;
    if (source[index] == '&' or source[index] == '$' or source[index] == '@') index += 1;
    if (index + 1 < limit and std.ascii.isAlphabetic(source[index]) and source[index + 1] == ':') index += 2;
    if (index >= limit or !scanner.isAsciiIdentifierStart(source[index])) return start;
    index = scanner.identifierEnd(source, index, .ascii);
    while (index < limit and source[index] == '#' and index + 1 < limit and scanner.isAsciiIdentifierStart(source[index + 1])) {
        index = scanner.identifierEnd(source, index + 1, .ascii);
    }
    return index;
}

fn dottedNameEnd(source: []const u8, start: usize, limit: usize) usize {
    var index = vimNameEnd(source, start, limit);
    while (index + 1 < limit and source[index] == '.' and scanner.isAsciiIdentifierStart(source[index + 1])) {
        index = scanner.identifierEnd(source, index + 1, .ascii);
    }
    return index;
}

fn commandNameStart(source: []const u8, start: usize, limit: usize) usize {
    var index = skipSpace(source, start, limit);
    while (index < limit and source[index] == '-') {
        while (index < limit and !std.ascii.isWhitespace(source[index])) index += 1;
        index = skipSpace(source, index, limit);
    }
    return index;
}

fn singleQuotedEnd(source: []const u8, start: usize, limit: usize) usize {
    var index = start + 1;
    while (index < limit) {
        if (source[index] != '\'') {
            index += scanner.validUtf8Length(source[index..]);
            continue;
        }
        index += 1;
        if (index < limit and source[index] == '\'') {
            index += 1;
            continue;
        }
        break;
    }
    return index;
}

fn skipSpace(source: []const u8, start: usize, limit: usize) usize {
    var index = start;
    while (index < limit and (source[index] == ' ' or source[index] == '\t')) index += 1;
    return index;
}

fn nextCodeByte(source: []const u8, after: usize, limit: usize) ?u8 {
    const index = skipSpace(source, after, limit);
    return if (index < limit) source[index] else null;
}

fn previousCodeByte(source: []const u8, before: usize, limit: usize) ?u8 {
    var index = before;
    while (index > limit and std.ascii.isWhitespace(source[index - 1])) index -= 1;
    return if (index > limit) source[index - 1] else null;
}

fn isVimNameStart(source: []const u8, index: usize, limit: usize) bool {
    if (index >= limit) return false;
    return scanner.isAsciiIdentifierStart(source[index]) or source[index] == '&' or source[index] == '$' or source[index] == '@';
}

fn hasScopePrefix(name: []const u8) bool {
    return name.len >= 3 and std.ascii.isAlphabetic(name[0]) and name[1] == ':';
}

fn isBindingCommand(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "const", "final", "let", "var" });
}

fn isKeyword(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "as", "break", "call", "catch", "const", "continue", "def", "else", "elseif", "enddef", "endfor", "endfunction", "endif", "endtry", "endwhile", "final", "for", "function", "if", "import", "in", "let", "return", "throw", "try", "var", "while" });
}

fn isType(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "blob", "bool", "dict", "float", "func", "list", "number", "string" });
}

fn isConstant(word: []const u8) bool {
    return scanner.wordIs(word, &.{ "null", "none", "true", "false" });
}
