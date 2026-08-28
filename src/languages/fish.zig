const std = @import("std");
const api = @import("../backend.zig");
const g = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "fish",
    .display_name = "Fish",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"#"},
        .keywords = &.{ "and", "begin", "break", "case", "else", "end", "for", "function", "if", "in", "not", "or", "return", "set", "switch", "time", "while" },
        .classify_identifiers = false,
        .identifier_dash = false,
    });
    var parser: StructureParser = .{ .source = source, .sink = sink };
    try parser.run();
}

const StructureParser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    command_position: bool = true,
    expected_function: bool = false,
    expected_variable: bool = false,
    function_arguments: bool = false,
    argument_names: bool = false,
    decorated_command: bool = false,

    fn run(parser: *StructureParser) api.HighlightError!void {
        while (parser.index < parser.source.len) switch (parser.source[parser.index]) {
            ' ', '\t', '\r' => parser.index += 1,
            '\n', ';' => {
                parser.command_position = true;
                parser.expected_variable = false;
                parser.function_arguments = false;
                parser.argument_names = false;
                parser.decorated_command = false;
                parser.index += 1;
            },
            '|' => {
                parser.command_position = true;
                parser.expected_variable = false;
                parser.function_arguments = false;
                parser.argument_names = false;
                parser.decorated_command = false;
                parser.index += if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '|') 2 else 1;
            },
            '#' => parser.skipLine(),
            '\'' => parser.skipSingleString(),
            '"' => try parser.scanDoubleString(),
            '\\' => parser.scanEscape(),
            '(' => {
                parser.command_position = true;
                parser.index += 1;
            },
            ')' => {
                parser.command_position = false;
                parser.index += 1;
            },
            '&' => {
                parser.command_position = true;
                parser.expected_variable = false;
                parser.index += if (std.mem.startsWith(u8, parser.source[parser.index..], "&&")) 2 else 1;
            },
            '>', '<', '^' => parser.scanRedirection(),
            '$' => try parser.scanVariable(),
            '-' => try parser.scanOption(),
            '/', '.' => {
                if (parser.command_position) {
                    try parser.scanCommandPath();
                } else {
                    parser.index += 1;
                }
            },
            'a'...'z', 'A'...'Z', '_' => try parser.scanWord(),
            else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
        };
    }

    fn scanWord(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and isWordContinue(parser.source[parser.index])) parser.index += 1;
        const word = parser.source[start..parser.index];

        if (parser.expected_function) {
            try parser.sink.add(start, parser.index, .function);
            parser.expected_function = false;
            parser.function_arguments = true;
            parser.command_position = false;
            return;
        }
        if (parser.expected_variable) {
            parser.scanVariableSuffix();
            try parser.sink.add(start, parser.index, .variable);
            parser.expected_variable = false;
            parser.command_position = false;
            return;
        }
        if (parser.argument_names) {
            try parser.sink.add(start, parser.index, .parameter);
            parser.command_position = false;
            return;
        }
        if (std.mem.eql(u8, word, "function")) {
            parser.expected_function = true;
            parser.command_position = false;
        } else if (std.mem.eql(u8, word, "for")) {
            parser.expected_variable = true;
            parser.command_position = false;
        } else if (std.mem.eql(u8, word, "set")) {
            try parser.sink.add(start, parser.index, .builtin);
            try parser.sink.add(start, parser.index, .function);
            parser.expected_variable = true;
            parser.command_position = false;
        } else if (wordIs(word, &.{ "and", "or", "if", "while", "not" })) {
            parser.command_position = true;
        } else if (wordIs(word, &.{ "begin", "break", "case", "else", "end", "in", "return", "switch" })) {
            parser.command_position = false;
        } else if (parser.function_arguments and !std.mem.eql(u8, word, "end")) {
            try parser.sink.add(start, parser.index, .parameter);
        } else if (parser.command_position) {
            try parser.sink.add(start, parser.index, .function);
            if (isBuiltin(word)) try parser.sink.add(start, parser.index, .builtin);
            parser.decorated_command = isCommandDecorator(word);
            parser.command_position = parser.decorated_command;
        }
    }

    fn scanVariable(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and parser.source[parser.index] == '$') parser.index += 1;
        while (parser.index < parser.source.len and isVariableContinue(parser.source[parser.index])) parser.index += 1;
        parser.scanVariableSuffix();
        if (parser.index > start + 1) try parser.sink.add(start, parser.index, .variable);
        parser.command_position = false;
    }

    fn scanVariableSuffix(parser: *StructureParser) void {
        while (parser.index < parser.source.len and parser.source[parser.index] == '[') {
            const close = std.mem.indexOfScalarPos(u8, parser.source, parser.index + 1, ']') orelse return;
            parser.index = close + 1;
        }
    }

    fn scanOption(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '-') parser.index += 1;
        while (parser.index < parser.source.len and isWordContinue(parser.source[parser.index])) parser.index += 1;
        if (parser.index > start + 1) {
            try parser.sink.add(start, parser.index, .attribute);
            if (parser.function_arguments) parser.argument_names = std.mem.eql(u8, parser.source[start..parser.index], "--argument-names") or std.mem.eql(u8, parser.source[start..parser.index], "-a");
        }
        if (!parser.decorated_command) parser.command_position = false;
    }

    fn scanDoubleString(parser: *StructureParser) api.HighlightError!void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            if (parser.source[parser.index] == '\\') {
                parser.index += @min(@as(usize, 2), parser.source.len - parser.index);
            } else if (parser.source[parser.index] == '$') {
                try parser.scanVariable();
            } else {
                const byte = parser.source[parser.index];
                parser.index += 1;
                if (byte == '"' or byte == '\n') break;
            }
        }
        parser.command_position = false;
    }

    fn skipSingleString(parser: *StructureParser) void {
        parser.index += 1;
        while (parser.index < parser.source.len) {
            const byte = parser.source[parser.index];
            parser.index += 1;
            if (byte == '\'' or byte == '\n') break;
        }
        parser.command_position = false;
    }

    fn scanEscape(parser: *StructureParser) void {
        if (parser.index + 1 >= parser.source.len) {
            parser.index += 1;
            return;
        }
        if (parser.source[parser.index + 1] == '\r' and parser.index + 2 < parser.source.len and parser.source[parser.index + 2] == '\n') {
            parser.index += 3;
        } else {
            parser.index += 2;
        }
    }

    fn scanRedirection(parser: *StructureParser) void {
        parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == parser.source[parser.index - 1]) parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '?') parser.index += 1;
        if (parser.index < parser.source.len and parser.source[parser.index] == '&') {
            parser.index += 1;
            while (parser.index < parser.source.len and std.ascii.isDigit(parser.source[parser.index])) parser.index += 1;
            return;
        }
        while (parser.index < parser.source.len and (parser.source[parser.index] == ' ' or parser.source[parser.index] == '\t')) parser.index += 1;
        if (parser.index >= parser.source.len or parser.source[parser.index] == '\n') return;
        if (parser.source[parser.index] == '\'' or parser.source[parser.index] == '"') {
            const quote = parser.source[parser.index];
            parser.index += 1;
            while (parser.index < parser.source.len) {
                if (parser.source[parser.index] == '\\' and quote == '"') {
                    parser.scanEscape();
                } else {
                    const byte = parser.source[parser.index];
                    parser.index += 1;
                    if (byte == quote) break;
                }
            }
            return;
        }
        while (parser.index < parser.source.len and !std.ascii.isWhitespace(parser.source[parser.index]) and
            std.mem.indexOfScalar(u8, ";|&", parser.source[parser.index]) == null)
        {
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
    }

    fn scanCommandPath(parser: *StructureParser) api.HighlightError!void {
        const start = parser.index;
        while (parser.index < parser.source.len and !std.ascii.isWhitespace(parser.source[parser.index]) and
            std.mem.indexOfScalar(u8, ";|&()<>", parser.source[parser.index]) == null)
        {
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        if (parser.index > start) try parser.sink.add(start, parser.index, .function);
        parser.decorated_command = false;
        parser.command_position = false;
    }

    fn skipLine(parser: *StructureParser) void {
        parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
    }
};

const wordIs = scanner.wordIs;

fn isBuiltin(word: []const u8) bool {
    return wordIs(word, &.{ "argparse", "builtin", "cd", "command", "commandline", "complete", "contains", "count", "echo", "emit", "eval", "exec", "functions", "math", "printf", "read", "set", "source", "status", "string", "test", "type" });
}

fn isCommandDecorator(word: []const u8) bool {
    return wordIs(word, &.{ "builtin", "command", "exec", "time" });
}

fn isWordContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}

fn isVariableContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}
