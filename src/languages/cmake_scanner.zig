const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const scanner = @import("scanner_support.zig");

pub fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink };
    try parser.run();
}

const Command = enum {
    none,
    generic,
    control,
    function_decl,
    macro_decl,
    binding,
    target_decl,
    target_use,
    foreach,
    set_property,
    get_property,
};

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    depth: usize = 0,
    pending_command: Command = .none,
    active_command: Command = .none,
    argument_index: usize = 0,
    expect_property: bool = false,
    expect_target: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '#') {
                if (bracketEnd(parser.source, parser.index + 1)) |end| {
                    try parser.sink.add(parser.index, end, .comment);
                    parser.index = end;
                } else {
                    const end = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                    try parser.sink.add(parser.index, end, .comment);
                    parser.index = end;
                }
                continue;
            }
            if (parser.source[parser.index] == '[') {
                if (bracketEnd(parser.source, parser.index)) |end| {
                    try parser.sink.add(parser.index, end, .string);
                    parser.index = end;
                    parser.consumeArgument();
                    continue;
                }
            }
            if (std.mem.startsWith(u8, parser.source[parser.index..], "$<")) {
                try parser.scanGeneratorExpression();
                parser.consumeArgument();
                continue;
            }
            if (variableReferencePrefix(parser.source[parser.index..]) != null) {
                try parser.scanVariableReference();
                parser.consumeArgument();
                continue;
            }
            switch (parser.source[parser.index]) {
                '"' => {
                    try parser.scanQuotedArgument();
                    parser.consumeArgument();
                },
                '(' => {
                    try parser.captureByte(.punctuation);
                    if (parser.depth == 0) {
                        parser.active_command = parser.pending_command;
                        parser.argument_index = 0;
                        parser.expect_property = false;
                        parser.expect_target = false;
                    }
                    parser.depth += 1;
                },
                ')' => {
                    try parser.captureByte(.punctuation);
                    parser.depth -|= 1;
                    if (parser.depth == 0) {
                        parser.active_command = .none;
                        parser.pending_command = .none;
                    }
                },
                ';', '[', ']', '{', '}', ',' => try parser.captureByte(.punctuation),
                '=', '<', '>', '!', '|', '&' => try parser.captureByte(.operator),
                '\\' => try parser.scanEscape(),
                '0'...'9' => {
                    try parser.scanNumber();
                    parser.consumeArgument();
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanWord(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = wordEnd(parser.source, parser.index);
        const word = parser.source[start..parser.index];

        if (parser.depth == 0 and nextNonSpaceAt(parser.source, parser.index) == '(') {
            parser.pending_command = commandFor(word);
            try parser.sink.add(start, parser.index, if (parser.pending_command == .control or parser.pending_command == .function_decl or parser.pending_command == .macro_decl) .keyword else .function);
            return;
        }

        if (parser.depth > 0 and parser.argumentHasStructuralRole()) {
            try parser.classifyArgument(start, parser.index);
        } else if (isBoolean(word)) {
            try parser.sink.add(start, parser.index, .boolean);
        } else if (isConstant(word)) {
            try parser.sink.add(start, parser.index, .constant);
        } else if (isArgumentKeyword(word)) {
            try parser.sink.add(start, parser.index, .keyword);
            if (std.ascii.eqlIgnoreCase(word, "PROPERTY") or std.ascii.eqlIgnoreCase(word, "PROPERTIES")) parser.expect_property = true;
            if (isTargetSelector(word)) parser.expect_target = true;
        } else if (parser.depth > 0) {
            try parser.classifyArgument(start, parser.index);
        }
        parser.consumeArgument();
    }

    fn argumentHasStructuralRole(parser: *const Parser) bool {
        if (parser.expect_property or parser.expect_target) return true;
        return switch (parser.active_command) {
            .function_decl, .macro_decl => true,
            .binding, .target_decl, .target_use, .foreach, .get_property => parser.argument_index == 0,
            .none, .generic, .control, .set_property => false,
        };
    }

    fn classifyArgument(parser: *Parser, start: usize, end: usize) api.HighlightError!void {
        if (parser.expect_property) {
            try parser.sink.add(start, end, .property);
            parser.expect_property = false;
            return;
        }
        if (parser.expect_target) {
            try parser.sink.add(start, end, .type);
            parser.expect_target = false;
            return;
        }
        switch (parser.active_command) {
            .function_decl => try parser.sink.add(start, end, if (parser.argument_index == 0) .function else .parameter),
            .macro_decl => try parser.sink.add(start, end, if (parser.argument_index == 0) .macro else .parameter),
            .binding => if (parser.argument_index == 0) try parser.sink.add(start, end, .variable),
            .target_decl, .target_use => if (parser.argument_index == 0) try parser.sink.add(start, end, .type),
            .foreach => if (parser.argument_index == 0) try parser.sink.add(start, end, .parameter),
            .set_property => {},
            .get_property => if (parser.argument_index == 0) try parser.sink.add(start, end, .variable),
            .control => try parser.sink.add(start, end, .variable),
            .none, .generic => {},
        }
    }

    fn scanQuotedArgument(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                try parser.scanEscape();
            } else if (std.mem.startsWith(u8, parser.source[parser.index..], "$<")) {
                try parser.scanGeneratorExpression();
            } else if (variableReferencePrefix(parser.source[parser.index..]) != null) {
                try parser.scanVariableReference();
            } else {
                const byte = parser.source[parser.index];
                parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
                if (byte == '"') break;
            }
        }
        try parser.sink.add(start, parser.index, .string);
    }

    fn scanVariableReference(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        const prefix_len = variableReferencePrefix(parser.source[start..]).?;
        parser.index += prefix_len;
        var depth: usize = 1;
        while (parser.index < parser.source.len and depth > 0) {
            if (variableReferencePrefix(parser.source[parser.index..])) |nested_len| {
                depth += 1;
                parser.index += nested_len;
            } else if (parser.source[parser.index] == '}') {
                depth -= 1;
                parser.index += 1;
            } else if (parser.source[parser.index] == '\\') {
                try parser.scanEscape();
            } else {
                parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
            }
        }
        try parser.sink.add(start, parser.index, .variable);
    }

    fn scanGeneratorExpression(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 2;
        var depth: usize = 1;
        while (parser.index < parser.source.len and depth > 0) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "$<")) {
                depth += 1;
                parser.index += 2;
            } else if (parser.source[parser.index] == '>') {
                depth -= 1;
                parser.index += 1;
            } else if (variableReferencePrefix(parser.source[parser.index..]) != null) {
                try parser.scanVariableReference();
            } else {
                parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
            }
        }
        try parser.sink.add(start, parser.index, .embedded);
    }

    fn scanEscape(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.escapeEnd(parser.source, parser.index);
        try parser.sink.add(start, parser.index, .escape);
    }

    fn scanNumber(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        while (parser.index < parser.source.len and (std.ascii.isDigit(parser.source[parser.index]) or parser.source[parser.index] == '.')) parser.index += 1;
        try parser.sink.add(start, parser.index, .number);
    }

    fn captureByte(parser: *Parser, scope: Scope) api.HighlightError!void {
        try parser.sink.add(parser.index, parser.index + 1, scope);
        parser.index += 1;
    }

    fn consumeArgument(parser: *Parser) void {
        if (parser.depth > 0) parser.argument_index += 1;
    }
};

fn bracketEnd(source: []const u8, start: usize) ?usize {
    if (start >= source.len or source[start] != '[') return null;
    var opener_end = start + 1;
    while (opener_end < source.len and source[opener_end] == '=') opener_end += 1;
    if (opener_end >= source.len or source[opener_end] != '[') return null;
    const equals = opener_end - start - 1;
    var index = opener_end + 1;
    while (index < source.len) {
        if (source[index] == ']') {
            var close = index + 1;
            var count: usize = 0;
            while (close < source.len and source[close] == '=' and count < equals) : (count += 1) close += 1;
            if (count == equals and close < source.len and source[close] == ']') return close + 1;
        }
        index += scanner.validUtf8Length(source[index..]);
    }
    return source.len;
}

fn variableReferencePrefix(source: []const u8) ?usize {
    if (std.mem.startsWith(u8, source, "${")) return 2;
    if (std.mem.startsWith(u8, source, "$ENV{")) return 5;
    if (std.mem.startsWith(u8, source, "$CACHE{")) return 7;
    return null;
}

fn wordEnd(source: []const u8, start: usize) usize {
    var index = start + 1;
    while (index < source.len and (std.ascii.isAlphanumeric(source[index]) or source[index] == '_' or source[index] == '-' or source[index] == '.')) index += 1;
    return index;
}

fn nextNonSpaceAt(source: []const u8, start: usize) ?u8 {
    var index = start;
    while (index < source.len and std.ascii.isWhitespace(source[index])) index += 1;
    return if (index < source.len) source[index] else null;
}

fn commandFor(word: []const u8) Command {
    if (scanner.wordIsIgnoreCase(word, &.{ "if", "else", "elseif", "endif", "endforeach", "endfunction", "endmacro", "endwhile", "include", "return", "while" })) return .control;
    if (std.ascii.eqlIgnoreCase(word, "function")) return .function_decl;
    if (std.ascii.eqlIgnoreCase(word, "macro")) return .macro_decl;
    if (scanner.wordIsIgnoreCase(word, &.{ "set", "unset", "option" })) return .binding;
    if (scanner.wordIsIgnoreCase(word, &.{ "add_executable", "add_library", "add_custom_target" })) return .target_decl;
    if (startsWithIgnoreCase(word, "target_")) return .target_use;
    if (std.ascii.eqlIgnoreCase(word, "foreach")) return .foreach;
    if (std.ascii.eqlIgnoreCase(word, "set_property")) return .set_property;
    if (std.ascii.eqlIgnoreCase(word, "get_property")) return .get_property;
    return .generic;
}

fn isBoolean(word: []const u8) bool {
    return scanner.wordIsIgnoreCase(word, &.{ "ON", "OFF", "TRUE", "FALSE", "YES", "NO", "Y", "N" });
}

fn isConstant(word: []const u8) bool {
    return scanner.wordIsIgnoreCase(word, &.{ "IGNORE", "NOTFOUND" }) or std.mem.endsWith(u8, word, "-NOTFOUND");
}

fn isArgumentKeyword(word: []const u8) bool {
    return scanner.wordIsIgnoreCase(word, &.{ "ALIAS", "APPEND", "CACHE", "COMMAND", "CONFIG", "DIRECTORY", "EXCLUDE_FROM_ALL", "GLOBAL", "IMPORTED", "IN", "INCLUDE_DIRECTORIES", "INTERFACE", "ITEMS", "LIBS", "LISTS", "MODULE", "NAME", "OBJECT", "PRIVATE", "PROPERTIES", "PROPERTY", "PUBLIC", "REQUIRED", "SHARED", "SOURCE", "STATIC", "STATUS", "TARGET", "TEST", "VERSION" });
}

fn isTargetSelector(word: []const u8) bool {
    return scanner.wordIsIgnoreCase(word, &.{ "TARGET", "SOURCE", "TEST" });
}

fn startsWithIgnoreCase(source: []const u8, prefix: []const u8) bool {
    return source.len >= prefix.len and std.ascii.eqlIgnoreCase(source[0..prefix.len], prefix);
}

test "CMake bracket arguments honor matching equals delimiters" {
    try std.testing.expectEqual(@as(?usize, 11), bracketEnd("[=[value]=] x", 0));
    try std.testing.expectEqual(@as(?usize, 12), bracketEnd("[[unfinished", 0));
}
