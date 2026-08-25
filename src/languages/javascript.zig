const std = @import("std");
const backend_api = @import("../backend.zig");
const javascript = @import("../parsers/javascript.zig");

const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "javascript",
    .display_name = "JavaScript",
    .kind = .parser_backed,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    try highlightLanguage(source, sink, .javascript);
}

pub fn highlightLanguage(
    source: []const u8,
    sink: *CaptureSink,
    mode: javascript.Mode,
) HighlightError!void {
    var tree = javascript.parse(sink.allocator, source, mode) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.SourceTooLarge => return error.SourceTooLarge,
        error.InvalidByteRange, error.InvalidTokenRange, error.UnorderedTokenRange => unreachable,
    };
    defer tree.deinit(sink.allocator);

    const roles = try sink.allocator.alloc(Roles, tree.tokens.len);
    defer sink.allocator.free(roles);
    @memset(roles, .{});

    for (tree.nodes) |node| switch (node.tag) {
        .variable_declaration, .root => {},
        .variable_binding => roles[node.main_token].variable = true,
        .function_declaration, .call_expression => roles[node.main_token].function = true,
        .class_declaration,
        .interface_declaration,
        .type_alias_declaration,
        .enum_declaration,
        .type_reference,
        => roles[node.main_token].type = true,
        .parameter => roles[node.main_token].parameter = true,
        .member_expression => roles[node.main_token].property = true,
    };

    for (tree.tokens, roles) |token, role| {
        try classifyToken(source, token, role, sink);
    }
}

const Roles = packed struct {
    variable: bool = false,
    function: bool = false,
    type: bool = false,
    parameter: bool = false,
    property: bool = false,

    fn any(roles: Roles) bool {
        return roles.variable or roles.function or roles.type or roles.parameter or roles.property;
    }
};

fn classifyToken(
    source: []const u8,
    token: javascript.Syntax.Token,
    roles: Roles,
    sink: *CaptureSink,
) HighlightError!void {
    const start: usize = token.start;
    const end: usize = token.end;

    switch (token.tag) {
        .eof => return,
        .invalid => try sink.add(start, end, .invalid),
        .identifier => if (!roles.any()) try sink.add(start, end, .variable),
        .private_identifier => if (!roles.any()) try sink.add(start, end, .property),
        .keyword => try sink.add(start, end, .keyword),
        .type_keyword => {
            try sink.add(start, end, .builtin);
            try sink.add(start, end, .type);
        },
        .builtin => try sink.add(start, end, .builtin),
        .boolean => try sink.add(start, end, .boolean),
        .constant => try sink.add(start, end, .constant),
        .number => try sink.add(start, end, .number),
        .string => try classifyString(source, start, end, false, sink),
        .template => try classifyString(source, start, end, true, sink),
        .comment => try sink.add(start, end, .comment),
        .documentation_comment => {
            try sink.add(start, end, .comment);
            try sink.add(start, end, .documentation);
        },
        .l_paren,
        .r_paren,
        .l_bracket,
        .r_bracket,
        .l_brace,
        .r_brace,
        .comma,
        .semicolon,
        .dot,
        .colon,
        => try sink.add(start, end, .punctuation),
        .operator => try sink.add(start, end, .operator),
    }

    if (roles.variable) try sink.add(start, end, .variable);
    if (roles.function) try sink.add(start, end, .function);
    if (roles.type) try sink.add(start, end, .type);
    if (roles.parameter) try sink.add(start, end, .parameter);
    if (roles.property) try sink.add(start, end, .property);
}

fn classifyString(
    source: []const u8,
    start: usize,
    end: usize,
    template: bool,
    sink: *CaptureSink,
) HighlightError!void {
    try sink.add(start, end, .string);
    var index = @min(start + 1, end);
    while (index < end) {
        if (source[index] == '\\') {
            const escape_end = escapeEnd(source[0..end], index);
            try sink.add(index, escape_end, .escape);
            index = escape_end;
        } else if (template and index + 1 < end and source[index] == '$' and source[index + 1] == '{') {
            try sink.add(index, index + 2, .punctuation);
            index += 2;
        } else {
            index += 1;
        }
    }
}

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
        else => 0,
    };
    var consumed: usize = 0;
    while (end < source.len and consumed < digits and std.ascii.isHex(source[end])) : (consumed += 1) {
        end += 1;
    }
    return end;
}

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}
