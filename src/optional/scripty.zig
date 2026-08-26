const std = @import("std");
const core = @import("native_syntax");
const scripty = @import("scripty");

pub const backend: core.Backend = .init(.{
    .canonical_name = "scripty",
    .display_name = "Scripty",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    try classifyLexical(source, sink);

    if (source.len > std.math.maxInt(u32)) return;

    var parser: scripty.Parser = .{};
    while (parser.next(source)) |node| {
        if (node.tag.isError()) {
            try sink.add(node.loc.start, node.loc.end, .invalid);
            break;
        }

        switch (node.tag) {
            .path => try classifyPath(source, node.loc.start, node.loc.end, sink),
            .call => try addUnique(node.loc.start, node.loc.end, .function, sink),
            .apply, .true, .false, .string, .integer, .float => {},
            .err_invalid_token,
            .err_unexpected_token,
            .err_missing_dollar,
            .err_not_identifier,
            .err_not_callable,
            .err_outside_call,
            .err_truncated,
            => unreachable,
        }
    }
}

fn classifyLexical(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    const IdentifierContext = enum { other, global, member };

    var index: usize = 0;
    var identifier_context: IdentifierContext = .other;
    while (index < source.len) {
        switch (source[index]) {
            ' ', '\n', '\t', '\r' => index += 1,
            '$' => {
                try sink.add(index, index + 1, .special);
                index += 1;
                identifier_context = .global;
            },
            '.' => {
                try sink.add(index, index + 1, .punctuation);
                index += 1;
                identifier_context = .member;
            },
            ',', '(', ')' => {
                try sink.add(index, index + 1, .punctuation);
                index += 1;
                identifier_context = .other;
            },
            '\'', '"' => {
                index = try classifyString(source, index, sink);
                identifier_context = .other;
            },
            '0'...'9', '-' => {
                index = try classifyNumber(source, index, sink);
                identifier_context = .other;
            },
            'a'...'z', 'A'...'Z', '_' => {
                const start = index;
                index += 1;
                while (index < source.len and isIdentifierContinue(source[index])) {
                    index += 1;
                }

                const identifier = source[start..index];
                if (std.mem.eql(u8, identifier, "true") or
                    std.mem.eql(u8, identifier, "false"))
                {
                    try sink.add(start, index, .boolean);
                } else switch (identifier_context) {
                    .global => try sink.add(start, index, .variable),
                    .member => if (!followedByCall(source, index)) {
                        try sink.add(start, index, .property);
                    },
                    .other => {},
                }
                identifier_context = .other;
            },
            else => {
                if (source[index] >= 0x80) {
                    if (validUtf8SequenceLength(source[index..])) |len| {
                        index += len;
                    } else {
                        try sink.add(index, index + 1, .invalid);
                        index += 1;
                    }
                } else {
                    try sink.add(index, index + 1, .invalid);
                    index += 1;
                }
                identifier_context = .other;
            },
        }
    }
}

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

fn classifyString(
    source: []const u8,
    start: usize,
    sink: *core.CaptureSink,
) core.HighlightError!usize {
    const quote = source[start];
    var index = start + 1;
    while (index < source.len) {
        if (source[index] == '\\' and index + 1 < source.len) {
            const escape_end = index + 1 +
                (validUtf8SequenceLength(source[index + 1 ..]) orelse 1);
            try sink.add(index, escape_end, .escape);
            index = escape_end;
            continue;
        }
        if (source[index] == quote) {
            index += 1;
            try sink.add(start, index, .string);
            return index;
        }
        index += 1;
    }

    try sink.add(start, source.len, .invalid);
    return source.len;
}

fn classifyNumber(
    source: []const u8,
    start: usize,
    sink: *core.CaptureSink,
) core.HighlightError!usize {
    var index = start;
    if (source[index] == '-') index += 1;

    var digit_count: usize = 0;
    var seen_dot = false;
    while (index < source.len) {
        switch (source[index]) {
            '0'...'9' => {
                digit_count += 1;
                index += 1;
            },
            '_' => index += 1,
            '.' => {
                if (seen_dot) break;
                seen_dot = true;
                index += 1;
            },
            else => break,
        }
    }

    if (digit_count == 0 or source[index - 1] == '.') {
        try sink.add(start, index, .invalid);
    } else {
        try sink.add(start, index, .number);
    }
    return index;
}

fn classifyPath(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    var index = start;
    const starts_at_global = index < end and source[index] == '$';
    if (starts_at_global) index += 1;

    var first_identifier = true;
    while (index < end) {
        if (!isIdentifierStart(source[index])) {
            index += 1;
            continue;
        }

        const identifier_start = index;
        index += 1;
        while (index < end and isIdentifierContinue(source[index])) index += 1;
        try addUnique(
            identifier_start,
            index,
            if (starts_at_global and first_identifier) .variable else .property,
            sink,
        );
        first_identifier = false;
    }
}

fn followedByCall(source: []const u8, start: usize) bool {
    var index = start;
    while (index < source.len) : (index += 1) {
        switch (source[index]) {
            ' ', '\n', '\t', '\r' => {},
            '(' => return true,
            else => return false,
        }
    }
    return false;
}

fn addUnique(
    start: usize,
    end: usize,
    scope: core.Scope,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    for (sink.captures()) |capture| {
        if (capture.span.start == start and
            capture.span.end == end and
            capture.scope == scope) return;
    }
    try sink.add(start, end, scope);
}

fn isIdentifierStart(byte: u8) bool {
    return switch (byte) {
        'a'...'z', 'A'...'Z', '_' => true,
        else => false,
    };
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or switch (byte) {
        '0'...'9', '?', '!' => true,
        else => false,
    };
}
