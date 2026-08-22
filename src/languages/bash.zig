const std = @import("std");
const backend_api = @import("../backend.zig");
const bash = @import("../parsers/bash.zig");

const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "bash",
    .display_name = "Bash",
    .kind = .parser_backed,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var tree = bash.parse(sink.allocator, source) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.SourceTooLarge => return error.SourceTooLarge,
        error.InvalidByteRange, error.InvalidTokenRange => unreachable,
    };
    defer tree.deinit(sink.allocator);

    const roles = try sink.allocator.alloc(Roles, tree.tokens.len);
    defer sink.allocator.free(roles);
    @memset(roles, .{});

    for (tree.nodes) |node| switch (node.tag) {
        .root,
        .simple_command,
        .argument,
        .redirection,
        .redirection_target,
        .function_definition,
        => {},
        .command_name => roles[node.main_token].command = true,
        .option => roles[node.main_token].option = true,
        .assignment => roles[node.main_token].assignment = true,
        .function_name => roles[node.main_token].function_name = true,
        .loop_variable => roles[node.main_token].loop_variable = true,
    };

    for (tree.tokens, roles) |token, role| {
        try classifyToken(source, token, role, sink);
    }
}

const Roles = packed struct {
    command: bool = false,
    option: bool = false,
    assignment: bool = false,
    function_name: bool = false,
    loop_variable: bool = false,
};

fn classifyToken(
    source: []const u8,
    token: bash.Syntax.Token,
    roles: Roles,
    sink: *CaptureSink,
) HighlightError!void {
    const start: usize = token.start;
    const end: usize = token.end;
    switch (token.tag) {
        .eof, .newline, .word => {},
        .invalid => try sink.add(start, end, .invalid),
        .number => try sink.add(start, end, .number),
        .keyword => try sink.add(start, end, .keyword),
        .comment => try sink.add(start, end, .comment),
        .string => {
            try sink.add(start, end, .string);
            if (start + 1 < end and source[start] == '$' and source[start + 1] == '\'') {
                try classifyEscapes(source, start + 2, end, sink);
            }
        },
        .expandable_string => try classifyExpandableString(source, start, end, sink),
        .variable => try sink.add(start, end, .variable),
        .command_substitution, .arithmetic_substitution => try sink.add(start, end, .embedded),
        .escape => try sink.add(start, end, .escape),
        .operator => try sink.add(start, end, .operator),
        .punctuation => try sink.add(start, end, .punctuation),
        .assignment => {},
        .heredoc_label => try sink.add(start, end, .label),
        .heredoc_body => try sink.add(start, end, .string),
    }

    if (roles.command or roles.function_name) try sink.add(start, end, .function);
    if (roles.command and bash.isBuiltin(source[start..end])) try sink.add(start, end, .builtin);
    if (roles.option) try sink.add(start, end, .constant);
    if (roles.loop_variable) try sink.add(start, end, .property);
    if (roles.assignment) try classifyAssignment(source, start, end, sink);
}

fn classifyAssignment(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    const parts = bash.assignmentParts(source[start..end]) orelse return;
    try sink.add(start, start + parts.name_end, .property);
    try sink.add(start + parts.name_end, start + parts.operator_end, .operator);
    const value = source[start + parts.operator_end .. end];
    if (value.len > 0 and isDecimalNumber(value)) {
        try sink.add(start + parts.operator_end, end, .number);
    }
}

fn classifyExpandableString(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    try sink.add(start, end, .string);
    var index = start + if (start + 1 < end and source[start] == '$' and source[start + 1] == '"')
        @as(usize, 2)
    else
        1;

    while (index < end) {
        if (source[index] == '\\') {
            const escape_end = @min(index + 2, end);
            try sink.add(index, escape_end, .escape);
            index = escape_end;
        } else if (source[index] == '$') {
            const expansion = dollarExpansion(source[0..end], index);
            if (expansion.end > index + 1) try sink.add(index, expansion.end, expansion.scope);
            index = expansion.end;
        } else if (source[index] == '`') {
            const substitution_end = backtickEnd(source[0..end], index);
            try sink.add(index, substitution_end, .embedded);
            index = substitution_end;
        } else {
            index += 1;
        }
    }
}

fn classifyEscapes(
    source: []const u8,
    first: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    var index = first;
    while (index < end) {
        if (source[index] == '\\') {
            const escape_end = @min(index + 2, end);
            try sink.add(index, escape_end, .escape);
            index = escape_end;
        } else {
            index += 1;
        }
    }
}

const Expansion = struct {
    end: usize,
    scope: @import("../scope.zig").Scope,
};

fn dollarExpansion(source: []const u8, start: usize) Expansion {
    if (start + 1 >= source.len) return .{ .end = start + 1, .scope = .variable };
    const next = source[start + 1];
    if (next == '{') return .{ .end = balancedEnd(source, start + 1, '{', '}'), .scope = .variable };
    if (next == '(') {
        const arithmetic = start + 2 < source.len and source[start + 2] == '(';
        return .{
            .end = if (arithmetic) arithmeticEnd(source, start + 3) else balancedEnd(source, start + 1, '(', ')'),
            .scope = .embedded,
        };
    }
    if (isIdentifierStart(next)) {
        var end = start + 2;
        while (end < source.len and isIdentifierContinue(source[end])) end += 1;
        return .{ .end = end, .scope = .variable };
    }
    if (std.ascii.isDigit(next) or std.mem.indexOfScalar(u8, "?*$#@!-_", next) != null) {
        return .{ .end = start + 2, .scope = .variable };
    }
    return .{ .end = start + 1, .scope = .variable };
}

fn balancedEnd(source: []const u8, open_index: usize, open: u8, close: u8) usize {
    var depth: usize = 1;
    var cursor = open_index + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '\\') {
            cursor = @min(cursor + 1, source.len);
            continue;
        }
        if (source[cursor] == open) depth += 1;
        if (source[cursor] == close) {
            depth -= 1;
            if (depth == 0) return cursor + 1;
        }
    }
    return source.len;
}

fn arithmeticEnd(source: []const u8, start: usize) usize {
    var depth: usize = 1;
    var cursor = start;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '(') depth += 1;
        if (source[cursor] == ')') {
            if (depth == 1 and cursor + 1 < source.len and source[cursor + 1] == ')') return cursor + 2;
            depth -= 1;
        }
    }
    return source.len;
}

fn backtickEnd(source: []const u8, start: usize) usize {
    var cursor = start + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '\\') {
            cursor = @min(cursor + 1, source.len);
            continue;
        }
        if (source[cursor] == '`') return cursor + 1;
    }
    return source.len;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isDecimalNumber(value: []const u8) bool {
    for (value) |byte| {
        if (!std.ascii.isDigit(byte) and byte != '_') return false;
    }
    return true;
}
