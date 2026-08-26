const std = @import("std");
const core = @import("native_syntax");
const ziggy = @import("ziggy");

pub const backend: core.Backend = .init(.{
    .canonical_name = "ziggy",
    .display_name = "Ziggy",
    .kind = .parser_backed,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    if (source.len == 0) return;

    const terminated = try sink.allocator.dupeSentinel(u8, source, 0);
    defer sink.allocator.free(terminated);

    var tokenizer: ziggy.Tokenizer = .init(.none);
    var current = tokenizer.next(terminated, false);
    const valid_utf8 = std.unicode.utf8ValidateSlice(source);

    while (current.tag != .eof) {
        const next = tokenizer.next(terminated, false);
        try classifyToken(source, valid_utf8, current, next.tag, sink);
        current = next;
    }
}

fn classifyToken(
    source: []const u8,
    valid_utf8: bool,
    token: ziggy.Tokenizer.Token,
    next_tag: ziggy.Tokenizer.Token.Tag,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    const start: usize = token.loc.start;
    const end: usize = token.loc.end;

    switch (token.tag) {
        .eof => {},
        .invalid => if (!valid_utf8 or
            (isUtf8Boundary(source, start) and isUtf8Boundary(source, end)))
        {
            try sink.add(start, end, .invalid);
        },
        .identifier => try sink.add(
            start,
            end,
            if (next_tag == .eql) .property else .constant,
        ),
        .union_case => {
            if (end > start + 1) try sink.add(start, end - 1, .constructor);
            try sink.add(end - 1, end, .punctuation);
        },
        .bytes, .bytes_line => try sink.add(start, end, .string),
        .integer, .float, .nan, .pos_inf, .neg_inf => try sink.add(start, end, .number),
        .null => try sink.add(start, end, .constant),
        .true, .false => try sink.add(start, end, .boolean),
        .comment_line => try sink.add(start, end, .comment),
        .eql => try sink.add(start, end, .operator),
        .comma, .colon, .rp, .dotlb, .lb, .rb, .lsb, .rsb => try sink.add(start, end, .punctuation),
        .eod => try sink.add(start, end, .special),
    }
}

fn isUtf8Boundary(source: []const u8, offset: usize) bool {
    if (offset > source.len) return false;
    return offset == source.len or source[offset] & 0xc0 != 0x80;
}
