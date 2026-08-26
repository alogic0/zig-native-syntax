const std = @import("std");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

pub const backend: Backend = .init(.{
    .canonical_name = "zig",
    .display_name = "Zig",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    if (source.len == 0) return;

    const terminated = try sink.allocator.dupeSentinel(u8, source, 0);
    defer sink.allocator.free(terminated);

    var tree = try std.zig.Ast.parse(sink.allocator, terminated, .{
        .recover = true,
        .mode = .zig,
    });
    defer tree.deinit(sink.allocator);

    var previous_end: usize = 0;

    for (0..tree.tokens.len) |token_index_usize| {
        const token_index: std.zig.Ast.TokenIndex = @intCast(token_index_usize);
        const start: usize = tree.tokenStart(token_index);
        try classifyComments(source, previous_end, start, sink);

        const tag = tree.tokenTag(token_index);
        if (tag == .eof) break;

        const end = start + tree.tokenSlice(token_index).len;
        try classifyToken(source, tag, start, end, sink);
        previous_end = end;
    }

    try classifyAstContext(&tree, sink);
}

fn classifyToken(
    source: []const u8,
    tag: std.zig.Token.Tag,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    switch (tag) {
        .eof => {},
        .invalid => try sink.add(start, end, .invalid),
        .identifier => try classifyIdentifier(source[start..end], start, end, sink),
        .string_literal, .char_literal => {
            try sink.add(start, end, .string);
            try classifyEscapes(source, start, end, sink);
        },
        .multiline_string_literal_line => try sink.add(start, end, .string),
        .builtin => try sink.add(start, end, .builtin),
        .number_literal => try sink.add(start, end, .number),
        .doc_comment, .container_doc_comment => {
            try sink.add(start, end, .comment);
            try sink.add(start, end, .documentation);
        },

        .keyword_addrspace,
        .keyword_align,
        .keyword_allowzero,
        .keyword_and,
        .keyword_anyframe,
        .keyword_anytype,
        .keyword_asm,
        .keyword_break,
        .keyword_callconv,
        .keyword_catch,
        .keyword_comptime,
        .keyword_const,
        .keyword_continue,
        .keyword_defer,
        .keyword_else,
        .keyword_enum,
        .keyword_errdefer,
        .keyword_error,
        .keyword_export,
        .keyword_extern,
        .keyword_fn,
        .keyword_for,
        .keyword_if,
        .keyword_inline,
        .keyword_noalias,
        .keyword_noinline,
        .keyword_nosuspend,
        .keyword_opaque,
        .keyword_or,
        .keyword_orelse,
        .keyword_packed,
        .keyword_pub,
        .keyword_resume,
        .keyword_return,
        .keyword_linksection,
        .keyword_struct,
        .keyword_suspend,
        .keyword_switch,
        .keyword_test,
        .keyword_threadlocal,
        .keyword_try,
        .keyword_union,
        .keyword_unreachable,
        .keyword_var,
        .keyword_volatile,
        .keyword_while,
        => try sink.add(start, end, .keyword),

        .l_paren,
        .r_paren,
        .semicolon,
        .l_brace,
        .r_brace,
        .l_bracket,
        .r_bracket,
        .period,
        .ellipsis2,
        .ellipsis3,
        .colon,
        .comma,
        => try sink.add(start, end, .punctuation),

        .bang,
        .pipe,
        .pipe_pipe,
        .pipe_equal,
        .equal,
        .equal_equal,
        .equal_angle_bracket_right,
        .bang_equal,
        .percent,
        .percent_equal,
        .period_asterisk,
        .caret,
        .caret_equal,
        .plus,
        .plus_plus,
        .plus_equal,
        .plus_percent,
        .plus_percent_equal,
        .plus_pipe,
        .plus_pipe_equal,
        .minus,
        .minus_equal,
        .minus_percent,
        .minus_percent_equal,
        .minus_pipe,
        .minus_pipe_equal,
        .asterisk,
        .asterisk_equal,
        .asterisk_percent,
        .asterisk_percent_equal,
        .asterisk_pipe,
        .asterisk_pipe_equal,
        .arrow,
        .slash,
        .slash_equal,
        .ampersand,
        .ampersand_equal,
        .question_mark,
        .angle_bracket_left,
        .angle_bracket_left_equal,
        .angle_bracket_angle_bracket_left,
        .angle_bracket_angle_bracket_left_equal,
        .angle_bracket_angle_bracket_left_pipe,
        .angle_bracket_angle_bracket_left_pipe_equal,
        .angle_bracket_right,
        .angle_bracket_right_equal,
        .angle_bracket_angle_bracket_right,
        .angle_bracket_angle_bracket_right_equal,
        .tilde,
        => try sink.add(start, end, .operator),
    }
}

fn classifyAstContext(
    tree: *const std.zig.Ast,
    sink: *CaptureSink,
) HighlightError!void {
    for (1..tree.nodes.len) |node_index_usize| {
        const node: std.zig.Ast.Node.Index = @fromBackingInt(@intCast(node_index_usize));
        const tag = tree.nodeTag(node);

        switch (tag) {
            .fn_proto_simple,
            .fn_proto_multi,
            .fn_proto_one,
            .fn_proto,
            => try classifyFunctionPrototype(tree, node, sink),

            .call_one,
            .call_one_comma,
            .call,
            .call_comma,
            => {
                var buffer: [1]std.zig.Ast.Node.Index = undefined;
                const call = tree.fullCall(&buffer, node).?;
                if (calleeToken(tree, call.ast.fn_expr)) |token| {
                    try addTokenScope(tree, token, .function, sink);
                }
            },

            .field_access => {
                const field_token = tree.nodeData(node).node_and_token[1];
                try addTokenScope(tree, field_token, .property, sink);
            },

            .container_field,
            .container_field_init,
            .container_field_align,
            => {
                const field = tree.fullContainerField(node).?;
                if (!field.ast.tuple_like and
                    tree.tokenTag(field.ast.main_token) == .identifier)
                {
                    try addTokenScope(tree, field.ast.main_token, .property, sink);
                }
            },

            .global_var_decl,
            .local_var_decl,
            .simple_var_decl,
            .aligned_var_decl,
            => try classifyTypeDeclaration(tree, node, sink),

            else => {},
        }
    }
}

fn classifyFunctionPrototype(
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    sink: *CaptureSink,
) HighlightError!void {
    var buffer: [1]std.zig.Ast.Node.Index = undefined;
    const fn_proto = tree.fullFnProto(&buffer, node).?;

    if (fn_proto.name_token) |name_token| {
        try addTokenScope(tree, name_token, .function, sink);
    }

    var iterator = fn_proto.iterate(tree);
    while (iterator.next()) |param| {
        if (param.name_token) |name_token| {
            try addTokenScope(tree, name_token, .parameter, sink);
        }
    }
}

fn classifyTypeDeclaration(
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
    sink: *CaptureSink,
) HighlightError!void {
    const var_decl = tree.fullVarDecl(node).?;
    const init_node = var_decl.ast.init_node.unwrap() orelse return;
    if (!isTypeInitializer(tree, init_node)) return;

    const name_token = var_decl.ast.mut_token + 1;
    if (tree.tokenTag(name_token) == .identifier) {
        try addTokenScope(tree, name_token, .type, sink);
    }
}

fn isTypeInitializer(
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
) bool {
    var buffer: [2]std.zig.Ast.Node.Index = undefined;
    if (tree.fullContainerDecl(&buffer, node) != null) return true;

    return switch (tree.nodeTag(node)) {
        .error_set_decl,
        .fn_proto_simple,
        .fn_proto_multi,
        .fn_proto_one,
        .fn_proto,
        => true,
        else => false,
    };
}

fn calleeToken(
    tree: *const std.zig.Ast,
    node: std.zig.Ast.Node.Index,
) ?std.zig.Ast.TokenIndex {
    return switch (tree.nodeTag(node)) {
        .identifier => tree.nodeMainToken(node),
        .field_access => tree.nodeData(node).node_and_token[1],
        .grouped_expression => calleeToken(tree, tree.nodeData(node).node_and_token[0]),
        else => null,
    };
}

fn addTokenScope(
    tree: *const std.zig.Ast,
    token: std.zig.Ast.TokenIndex,
    scope: Scope,
    sink: *CaptureSink,
) HighlightError!void {
    const start: usize = tree.tokenStart(token);
    try sink.add(start, start + tree.tokenSlice(token).len, scope);
}

fn classifyIdentifier(
    identifier: []const u8,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    if (std.mem.eql(u8, identifier, "true") or
        std.mem.eql(u8, identifier, "false"))
    {
        try sink.add(start, end, .boolean);
    } else if (std.mem.eql(u8, identifier, "null") or
        std.mem.eql(u8, identifier, "undefined"))
    {
        try sink.add(start, end, .constant);
    } else if (std.zig.primitives.isPrimitive(identifier)) {
        try sink.add(start, end, .builtin);
        try sink.add(start, end, .type);
    } else {
        try sink.add(start, end, .variable);
    }
}

fn classifyComments(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    var index = start;
    while (index + 1 < end) {
        if (source[index] != '/' or source[index + 1] != '/') {
            index += 1;
            continue;
        }

        const comment_start = index;
        index += 2;
        while (index < end and source[index] != '\n' and source[index] != '\r') {
            index += 1;
        }
        try sink.add(comment_start, index, .comment);
    }
}

fn classifyEscapes(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *CaptureSink,
) HighlightError!void {
    var index = start;
    while (index < end) : (index += 1) {
        if (source[index] != '\\') continue;

        var escape_end = if (index + 1 < end and source[index + 1] >= 0x80)
            index + 1 + (validUtf8SequenceLength(source[index + 1 .. end]) orelse 1)
        else
            @min(index + 2, end);
        if (index + 1 < end and source[index + 1] == 'x') {
            escape_end = @min(index + 4, end);
        } else if (index + 2 < end and
            source[index + 1] == 'u' and
            source[index + 2] == '{')
        {
            escape_end = index + 3;
            while (escape_end < end and source[escape_end] != '}') {
                escape_end += 1;
            }
            if (escape_end < end) escape_end += 1;
        }

        try sink.add(index, escape_end, .escape);
        index = escape_end - 1;
    }
}

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

fn hasCapture(
    captures: []const @import("../capture.zig").Capture,
    source: []const u8,
    expected_source: []const u8,
    expected_scope: Scope,
) bool {
    for (captures) |item| {
        if (item.scope == expected_scope and
            std.mem.eql(u8, item.span.slice(source) catch return false, expected_source))
        {
            return true;
        }
    }
    return false;
}

test "Zig backend classifies lexical roles" {
    const source =
        \\/// Documentation.
        \\const answer: u8 = @intCast(42); // ordinary
        \\const enabled = true;
        \\const missing = null;
        \\const text = "line\\n\\u{21}";
    ;
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try backend.highlight(source, &sink);
    const captures = sink.captures();

    try std.testing.expect(hasCapture(captures, source, "const", .keyword));
    try std.testing.expect(hasCapture(captures, source, "answer", .variable));
    try std.testing.expect(hasCapture(captures, source, "u8", .builtin));
    try std.testing.expect(hasCapture(captures, source, "u8", .type));
    try std.testing.expect(hasCapture(captures, source, "@intCast", .builtin));
    try std.testing.expect(hasCapture(captures, source, "42", .number));
    try std.testing.expect(hasCapture(captures, source, "true", .boolean));
    try std.testing.expect(hasCapture(captures, source, "null", .constant));
    try std.testing.expect(hasCapture(captures, source, "/// Documentation.", .comment));
    try std.testing.expect(hasCapture(captures, source, "/// Documentation.", .documentation));
    try std.testing.expect(hasCapture(captures, source, "// ordinary", .comment));
    try std.testing.expect(hasCapture(captures, source, "\\n", .escape));
    try std.testing.expect(hasCapture(captures, source, "\\u{21}", .escape));
}

test "Zig backend adds reliable AST context" {
    const source =
        \\const Thing = struct {
        \\    field: u32,
        \\};
        \\const Failure = error{Bad};
        \\const Callback = fn (argument: u32) void;
        \\fn compute(input: Thing) void {
        \\    const object: Thing = .{ .field = 1 };
        \\    object.field = compute(input);
        \\    object.method(input);
        \\}
    ;
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try backend.highlight(source, &sink);
    const captures = sink.captures();

    try std.testing.expectEqual(backend_api.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expect(hasCapture(captures, source, "Thing", .type));
    try std.testing.expect(hasCapture(captures, source, "Failure", .type));
    try std.testing.expect(hasCapture(captures, source, "Callback", .type));
    try std.testing.expect(hasCapture(captures, source, "compute", .function));
    try std.testing.expect(hasCapture(captures, source, "input", .parameter));
    try std.testing.expect(hasCapture(captures, source, "argument", .parameter));
    try std.testing.expect(hasCapture(captures, source, "field", .property));
    try std.testing.expect(hasCapture(captures, source, "method", .property));
    try std.testing.expect(hasCapture(captures, source, "method", .function));
}

test "Zig backend retains lexical output after parser recovery" {
    const source = "fn incomplete(value: u32) void { const after =";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try backend.highlight(source, &sink);
    const captures = sink.captures();

    try std.testing.expect(hasCapture(captures, source, "fn", .keyword));
    try std.testing.expect(hasCapture(captures, source, "incomplete", .variable));
    try std.testing.expect(hasCapture(captures, source, "after", .variable));
}

test "Zig backend preserves useful tokens around invalid source" {
    const source = "const before = 1; \\ invalid\nconst after = 2;";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try backend.highlight(source, &sink);
    const captures = sink.captures();

    try std.testing.expect(hasCapture(captures, source, "before", .variable));
    try std.testing.expect(hasCapture(captures, source, "\\", .invalid));
    try std.testing.expect(hasCapture(captures, source, "after", .variable));
}

test "Zig backend handles embedded NUL and empty source" {
    const source = "const\x00value";
    var sink: CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try std.testing.expect(hasCapture(sink.captures(), source, "\x00", .invalid));

    var empty_sink: CaptureSink = .init(std.testing.allocator, 0);
    defer empty_sink.deinit();
    try backend.highlight("", &empty_sink);
    try std.testing.expectEqual(@as(usize, 0), empty_sink.captures().len);
}

fn highlightAllocationCase(allocator: std.mem.Allocator) !void {
    const source = "const answer: usize = 42;";
    var sink: CaptureSink = .init(allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
}

test "Zig backend handles every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        highlightAllocationCase,
        .{},
    );
}
