const backend_api = @import("../backend.zig");
const rust = @import("../parsers/rust.zig");

const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;

pub const backend: Backend = .init(.{
    .canonical_name = "rust",
    .display_name = "Rust",
    .kind = .parser_backed,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var tree = rust.parse(sink.allocator, source) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.SourceTooLarge => return error.SourceTooLarge,
        error.InvalidByteRange, error.InvalidTokenRange, error.UnorderedTokenRange => unreachable,
    };
    defer tree.deinit(sink.allocator);

    const roles = try sink.allocator.alloc(Roles, tree.tokens.len);
    defer sink.allocator.free(roles);
    @memset(roles, .{});

    for (tree.nodes) |node| switch (node.tag) {
        .root => {},
        .function_declaration, .call_expression => roles[node.main_token].function = true,
        .parameter => roles[node.main_token].parameter = true,
        .type_declaration, .type_alias_declaration, .type_reference, .impl_target => {
            roles[node.main_token].type = true;
        },
        .module_declaration => roles[node.main_token].namespace = true,
        .constant_declaration, .static_declaration => roles[node.main_token].constant = true,
        .variable_binding => roles[node.main_token].variable = true,
        .field_declaration, .member_expression => roles[node.main_token].property = true,
        .enum_variant => roles[node.main_token].constructor = true,
    };

    for (tree.tokens, roles) |token, role| {
        try classifyToken(source, token, role, sink);
    }
}

const Roles = packed struct {
    function: bool = false,
    parameter: bool = false,
    type: bool = false,
    namespace: bool = false,
    constant: bool = false,
    variable: bool = false,
    property: bool = false,
    constructor: bool = false,

    fn any(roles: Roles) bool {
        return roles.function or roles.parameter or roles.type or roles.namespace or
            roles.constant or roles.variable or roles.property or roles.constructor;
    }
};

fn classifyToken(
    source: []const u8,
    token: rust.Syntax.Token,
    roles: Roles,
    sink: *CaptureSink,
) HighlightError!void {
    const start: usize = token.start;
    const end: usize = token.end;

    switch (token.tag) {
        .eof => return,
        .invalid => try sink.add(start, end, .invalid),
        .identifier => if (!roles.any()) try sink.add(start, end, .variable),
        .keyword => try sink.add(start, end, .keyword),
        .boolean => try sink.add(start, end, .boolean),
        .primitive_type => {
            try sink.add(start, end, .builtin);
            try sink.add(start, end, .type);
        },
        .number => try sink.add(start, end, .number),
        .string => {
            try sink.add(start, end, .string);
            if (!isRawString(source[start..end])) try classifyEscapes(source, start, end, sink);
        },
        .lifetime => try sink.add(start, end, .label),
        .comment => try sink.add(start, end, .comment),
        .documentation_comment => {
            try sink.add(start, end, .comment);
            try sink.add(start, end, .documentation);
        },
        .attribute => try sink.add(start, end, .attribute),
        .macro => try sink.add(start, end, .macro),
        .operator => try sink.add(start, end, .operator),
        .punctuation => try sink.add(start, end, .punctuation),
    }

    if (roles.function) try sink.add(start, end, .function);
    if (roles.parameter) try sink.add(start, end, .parameter);
    if (roles.type) try sink.add(start, end, .type);
    if (roles.namespace) try sink.add(start, end, .namespace);
    if (roles.constant) try sink.add(start, end, .constant);
    if (roles.variable) try sink.add(start, end, .variable);
    if (roles.property) try sink.add(start, end, .property);
    if (roles.constructor) try sink.add(start, end, .constructor);
}

fn classifyEscapes(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    var index = start;
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

fn isRawString(text: []const u8) bool {
    if (text.len == 0) return false;
    if (text[0] == 'r') return text.len > 1 and (text[1] == '"' or text[1] == '#');
    return text.len > 2 and text[0] == 'b' and text[1] == 'r' and
        (text[2] == '"' or text[2] == '#');
}
