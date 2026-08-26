const std = @import("std");
const utf8 = @import("../utf8.zig");
const backend_api = @import("../backend.zig");
const Backend = backend_api.Backend;
const CaptureSink = backend_api.CaptureSink;
const HighlightError = backend_api.HighlightError;
const Scope = @import("../scope.zig").Scope;

const Container = enum { array, inline_table };

pub const backend: Backend = .init(.{
    .canonical_name = "toml",
    .display_name = "TOML",
    .kind = .lexical,
    .support_level = .verified_lexical,
}, highlight);

fn highlight(source: []const u8, sink: *CaptureSink) HighlightError!void {
    var scanner: Scanner = .{ .source = source, .sink = sink };
    try scanner.run();
}

const Scanner = struct {
    source: []const u8,
    sink: *CaptureSink,
    index: usize = 0,
    table_depth: u2 = 0,
    mode: enum { key, value, table } = .key,
    containers: [32]Container = undefined,
    container_depth: usize = 0,

    fn run(scanner: *Scanner) HighlightError!void {
        while (scanner.index < scanner.source.len) switch (scanner.source[scanner.index]) {
            '#' => try scanner.scanComment(),
            '\n' => {
                scanner.table_depth = 0;
                if (scanner.container_depth == 0) scanner.mode = .key;
                scanner.index += 1;
            },
            '"', '\'' => try scanner.scanString(scanner.source[scanner.index]),
            '[' => {
                if (scanner.mode == .key or scanner.mode == .table) {
                    scanner.mode = .table;
                    scanner.table_depth = @min(scanner.table_depth + 1, 2);
                } else {
                    scanner.pushContainer(.array);
                }
                try scanner.captureByte(.punctuation);
            },
            ']' => {
                if (scanner.mode == .table) {
                    if (scanner.table_depth > 0) scanner.table_depth -= 1;
                } else if (scanner.topContainer() == .array) {
                    scanner.popContainer();
                }
                try scanner.captureByte(.punctuation);
            },
            '=' => {
                try scanner.captureByte(.operator);
                scanner.mode = .value;
            },
            '{' => {
                scanner.pushContainer(.inline_table);
                scanner.mode = .key;
                try scanner.captureByte(.punctuation);
            },
            '}' => {
                if (scanner.topContainer() == .inline_table) scanner.popContainer();
                scanner.mode = .value;
                try scanner.captureByte(.punctuation);
            },
            ',' => {
                try scanner.captureByte(.punctuation);
                scanner.mode = if (scanner.topContainer() == .inline_table) .key else .value;
            },
            '.' => try scanner.captureByte(.punctuation),
            '+', '-', '0'...'9' => try scanner.scanNumberLike(),
            else => if (isBareKeyByte(scanner.source[scanner.index])) {
                try scanner.scanWord();
            } else {
                scanner.index += 1;
            },
        };
    }

    fn pushContainer(scanner: *Scanner, container: Container) void {
        if (scanner.container_depth == scanner.containers.len) return;
        scanner.containers[scanner.container_depth] = container;
        scanner.container_depth += 1;
    }

    fn popContainer(scanner: *Scanner) void {
        if (scanner.container_depth > 0) scanner.container_depth -= 1;
    }

    fn topContainer(scanner: *const Scanner) ?Container {
        if (scanner.container_depth == 0) return null;
        return scanner.containers[scanner.container_depth - 1];
    }

    fn captureByte(scanner: *Scanner, scope: Scope) HighlightError!void {
        try scanner.sink.add(scanner.index, scanner.index + 1, scope);
        scanner.index += 1;
    }

    fn scanComment(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index = std.mem.indexOfScalarPos(u8, scanner.source, start, '\n') orelse scanner.source.len;
        try scanner.sink.add(start, scanner.index, .comment);
    }

    fn scanString(scanner: *Scanner, quote: u8) HighlightError!void {
        const start = scanner.index;
        const triple = scanner.index + 2 < scanner.source.len and
            scanner.source[scanner.index + 1] == quote and
            scanner.source[scanner.index + 2] == quote;
        var cursor = scanner.index + if (triple) @as(usize, 3) else 1;
        while (cursor < scanner.source.len) {
            if (quote == '"' and scanner.source[cursor] == '\\') {
                const escape_end = tomlEscapeEnd(scanner.source, cursor);
                try scanner.sink.add(cursor, escape_end, .escape);
                cursor = escape_end;
                continue;
            }
            if (triple) {
                if (cursor + 2 < scanner.source.len and
                    scanner.source[cursor] == quote and
                    scanner.source[cursor + 1] == quote and
                    scanner.source[cursor + 2] == quote)
                {
                    cursor += 3;
                    break;
                }
            } else if (scanner.source[cursor] == quote) {
                cursor += 1;
                break;
            }
            cursor += 1;
        }

        const scope: Scope = switch (scanner.mode) {
            .table => .namespace,
            .key => .property,
            .value => .string,
        };
        try scanner.sink.add(start, cursor, scope);
        scanner.index = cursor;
    }

    fn scanNumberLike(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        if (scanner.mode != .value) {
            while (scanner.index < scanner.source.len and isBareKeyByte(scanner.source[scanner.index])) {
                scanner.index += 1;
            }
            try scanner.sink.add(start, scanner.index, if (scanner.mode == .table) .namespace else .property);
            return;
        }
        while (scanner.index < scanner.source.len) {
            const byte = scanner.source[scanner.index];
            if (std.ascii.isAlphanumeric(byte) or
                byte == '_' or byte == '.' or byte == ':' or byte == '+' or byte == '-')
            {
                scanner.index += 1;
            } else break;
        }
        try scanner.sink.add(start, scanner.index, .number);
    }

    fn scanWord(scanner: *Scanner) HighlightError!void {
        const start = scanner.index;
        scanner.index += 1;
        while (scanner.index < scanner.source.len and isBareKeyByte(scanner.source[scanner.index])) {
            scanner.index += 1;
        }
        const word = scanner.source[start..scanner.index];
        if (scanner.mode == .table) {
            try scanner.sink.add(start, scanner.index, .namespace);
        } else if (scanner.mode == .key) {
            try scanner.sink.add(start, scanner.index, .property);
        } else if (std.mem.eql(u8, word, "true") or std.mem.eql(u8, word, "false")) {
            try scanner.sink.add(start, scanner.index, .boolean);
        } else if (std.mem.eql(u8, word, "inf") or std.mem.eql(u8, word, "nan")) {
            try scanner.sink.add(start, scanner.index, .number);
        }
    }
};

fn tomlEscapeEnd(source: []const u8, start: usize) usize {
    if (start + 1 >= source.len or source[start + 1] >= 0x80) {
        return utf8.escapedSequenceEnd(source, start, source.len);
    }
    var end = start + 2;
    const digits: usize = switch (source[start + 1]) {
        'u' => 4,
        'U' => 8,
        else => 0,
    };
    var consumed: usize = 0;
    while (end < source.len and consumed < digits and std.ascii.isHex(source[end])) : (consumed += 1) {
        end += 1;
    }
    return end;
}

fn isBareKeyByte(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-';
}
