const std = @import("std");
const core = @import("native_syntax");
const ziggy = @import("ziggy");

pub const backend: core.Backend = .init(.{
    .canonical_name = "ziggy-schema",
    .display_name = "Ziggy Schema",
    .kind = .parser_backed,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    if (source.len == 0) return;

    const terminated = try sink.allocator.dupeSentinel(u8, source, 0);
    defer sink.allocator.free(terminated);

    try classifyTokens(terminated, sink);

    var ast = try ziggy.schema.Ast.init(sink.allocator, terminated);
    defer ast.deinit(sink.allocator);
    try classifyAstContext(&ast, terminated, sink);
}

fn classifyTokens(source: [:0]const u8, sink: *core.CaptureSink) core.HighlightError!void {
    var tokenizer: ziggy.schema.Tokenizer = .init;
    const original = source[0..sink.source_len];
    const valid_utf8 = std.unicode.utf8ValidateSlice(original);
    while (true) {
        const token = tokenizer.next(source);
        if (token.tag == .eof) break;

        const start: usize = token.loc.start;
        const end: usize = token.loc.end;
        switch (token.tag) {
            .eof => unreachable,
            .invalid => if (!valid_utf8 or
                (isUtf8Boundary(original, start) and isUtf8Boundary(original, end)))
            {
                try sink.add(start, end, .invalid);
            },
            .root_sigil => try sink.add(start, end, .special),
            .struct_kw, .union_kw => try sink.add(start, end, .keyword),
            .any_kw,
            .int_kw,
            .float_kw,
            .slice_sigil,
            .dict_sigil,
            .bytes_kw,
            .bool_kw,
            .opt_int_kw,
            .opt_float_kw,
            .opt_slice_sigil,
            .opt_dict_sigil,
            .opt_bytes_kw,
            .opt_bool_kw,
            => {
                try sink.add(start, end, .builtin);
                try sink.add(start, end, .type);
            },
            .identifier, .opt_identifier => {},
            .eq => try sink.add(start, end, .operator),
            .lb, .rb, .colon, .comma => try sink.add(start, end, .punctuation),
            .doc_comment_line => {
                try sink.add(start, end, .comment);
                try sink.add(start, end, .documentation);
            },
        }
    }
}

fn isUtf8Boundary(source: []const u8, offset: usize) bool {
    if (offset > source.len) return false;
    return offset == source.len or source[offset] & 0xc0 != 0x80;
}

fn classifyAstContext(
    ast: *const ziggy.schema.Ast,
    source: [:0]const u8,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    for (ast.nodes) |node| {
        switch (node.tag) {
            .@"struct", .@"union" => {
                var tokenizer = ziggy.schema.Tokenizer.initFrom(node.loc.start);
                _ = tokenizer.next(source);
                const name = tokenizer.next(source);
                if (name.tag == .identifier) try addToken(name, .type, sink);
            },
            .struct_field, .union_field => {
                var tokenizer = ziggy.schema.Tokenizer.initFrom(node.loc.start);
                const name = tokenizer.next(source);
                if (name.tag == .identifier) try addToken(name, .property, sink);
            },
            .root_expr, .type_expr => try classifyTypeExpression(node.loc, source, sink),
            .root => {},
        }
    }
}

fn classifyTypeExpression(
    loc: ziggy.schema.Tokenizer.Token.Loc,
    source: [:0]const u8,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    if (loc.start > loc.end or loc.end > source.len) return;

    var tokenizer = ziggy.schema.Tokenizer.initFrom(loc.start);
    while (true) {
        const token = tokenizer.next(source);
        if (token.tag == .eof or token.loc.start >= loc.end) break;
        if (token.tag == .identifier or token.tag == .opt_identifier) {
            try addToken(token, .type, sink);
        }
    }
}

fn addToken(
    token: ziggy.schema.Tokenizer.Token,
    scope: core.Scope,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    try sink.add(token.loc.start, token.loc.end, scope);
}
