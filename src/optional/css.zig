const std = @import("std");
const core = @import("native_syntax");
const css = @import("superhtml_css");

pub const backend: core.Backend = .init(.{
    .canonical_name = "css",
    .display_name = "CSS",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    if (source.len > std.math.maxInt(u32)) return;

    var tokenizer: css.Tokenizer = .{ .return_comments = true };
    var in_declaration_value = false;
    var pending_property = false;
    while (tokenizer.next(source)) |token| {
        const span = token.span();
        switch (token) {
            .ident => |ident| {
                if (looksLikeProperty(source, ident)) {
                    try addSpan(source.len, ident, .property, sink);
                    pending_property = true;
                } else {
                    try addSpan(
                        source.len,
                        ident,
                        if (in_declaration_value) .constant else .tag,
                        sink,
                    );
                    pending_property = false;
                }
            },
            .function => |function| {
                if (function.end > function.start) {
                    try sink.add(function.start, function.end - 1, .function);
                    try sink.add(function.end - 1, function.end, .punctuation);
                }
                pending_property = false;
            },
            .at_keyword => |keyword| {
                try addSpan(source.len, keyword, .keyword, sink);
                pending_property = false;
            },
            .hash => |hash| {
                try addSpan(source.len, hash, .constant, sink);
                pending_property = false;
            },
            .string => |string| {
                try addSpan(source.len, string, .string, sink);
                pending_property = false;
            },
            .bad_string => |string| {
                try addSpan(source.len, string, .invalid, sink);
                pending_property = false;
            },
            .url => |url| {
                try classifyUrl(source, url, .string, sink);
                pending_property = false;
            },
            .bad_url => |url| {
                try classifyUrl(source, url, .invalid, sink);
                pending_property = false;
            },
            .number => |number| {
                try addSpan(source.len, number, .number, sink);
                pending_property = false;
            },
            .percentage => |percentage| {
                try addSpan(source.len, percentage, .number, sink);
                pending_property = false;
            },
            .dimension => |dimension| {
                try addSpan(source.len, dimension.number, .number, sink);
                try addSpan(source.len, dimension.unit, .type, sink);
                pending_property = false;
            },
            .comment => |comment| try addSpan(source.len, comment, .comment, sink),
            .cdo, .cdc => try addSpan(source.len, span, .comment, sink),
            .colon => |index| {
                try sink.add(index, index + 1, .punctuation);
                if (pending_property) in_declaration_value = true;
                pending_property = false;
            },
            .semicolon => |index| {
                try sink.add(index, index + 1, .punctuation);
                in_declaration_value = false;
                pending_property = false;
            },
            .open_curly => |index| {
                try sink.add(index, index + 1, .punctuation);
                in_declaration_value = false;
                pending_property = false;
            },
            .close_curly => |index| {
                try sink.add(index, index + 1, .punctuation);
                in_declaration_value = false;
                pending_property = false;
            },
            .comma,
            .open_square,
            .close_square,
            .open_paren,
            .close_paren,
            => |index| {
                try sink.add(index, index + 1, .punctuation);
                pending_property = false;
            },
            .delim => |index| {
                if (!std.ascii.isWhitespace(source[index])) {
                    try sink.add(index, index + 1, .operator);
                }
                pending_property = false;
            },
            .err => |token_error| {
                try addSpan(source.len, token_error.span, .invalid, sink);
                pending_property = false;
            },
        }
    }
}

fn looksLikeProperty(source: []const u8, identifier: css.Span) bool {
    const name = identifier.slice(source);
    var index = skipTrivia(source, identifier.end);
    if (index >= source.len or source[index] != ':') return false;
    if (std.mem.startsWith(u8, name, "--")) return true;
    index += 1;

    var paren_depth: usize = 0;
    var square_depth: usize = 0;
    var quote: ?u8 = null;
    while (index < source.len) : (index += 1) {
        const byte = source[index];
        if (quote) |active_quote| {
            if (byte == '\\') {
                index += @intFromBool(index + 1 < source.len);
            } else if (byte == active_quote) {
                quote = null;
            }
            continue;
        }
        if (byte == '\'' or byte == '"') {
            quote = byte;
            continue;
        }
        switch (byte) {
            '(' => paren_depth += 1,
            ')' => paren_depth -|= 1,
            '[' => square_depth += 1,
            ']' => square_depth -|= 1,
            '{' => if (paren_depth == 0 and square_depth == 0) return false,
            ';', '}' => if (paren_depth == 0 and square_depth == 0) return true,
            else => {},
        }
    }
    return true;
}

fn skipTrivia(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len) {
        if (std.ascii.isWhitespace(source[index])) {
            index += 1;
        } else if (index + 1 < source.len and
            source[index] == '/' and source[index + 1] == '*')
        {
            index += 2;
            while (index + 1 < source.len and
                (source[index] != '*' or source[index + 1] != '/')) index += 1;
            if (index + 1 < source.len) index += 2;
        } else break;
    }
    return index;
}

fn classifyUrl(
    source: []const u8,
    url: css.Span,
    scope: core.Scope,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    try addSpan(source.len, url, scope, sink);
    if (url.start >= 4 and std.ascii.eqlIgnoreCase(source[url.start - 4 .. url.start - 1], "url")) {
        try sink.add(url.start - 4, url.start - 1, .function);
        try sink.add(url.start - 1, url.start, .punctuation);
    }
    if (url.end < source.len and source[url.end] == ')') {
        try sink.add(url.end, url.end + 1, .punctuation);
    }
}

fn addSpan(
    source_len: usize,
    span: css.Span,
    scope: core.Scope,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    if (span.start > span.end or span.end > source_len) return;
    try sink.add(span.start, span.end, scope);
}
