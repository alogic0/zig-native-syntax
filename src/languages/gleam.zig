const std = @import("std");
const api = @import("../backend.zig");
const Capture = @import("../capture.zig").Capture;
const Scope = @import("../scope.zig").Scope;
const generic = @import("generic.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "gleam",
    .display_name = "Gleam",
    .kind = .parser_backed,
}, highlight);

const keywords = &.{
    "as",   "assert", "auto",   "case", "const",  "delegate", "echo", "else",
    "fn",   "if",     "import", "let",  "opaque", "panic",    "pub",  "todo",
    "type", "use",
};
const types = &.{ "BitArray", "Bool", "Float", "Int", "List", "Nil", "Result", "String" };

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = &.{"//"},
        .keywords = keywords,
        .types = types,
        .booleans = &.{ "True", "False" },
        .classify_identifiers = true,
        .identifier_dash = false,
    });
    var parser: Parser = .{
        .source = source,
        .sink = sink,
        .capture_count = sink.captures().len,
    };
    try parser.run();
}

const Parser = struct {
    const BindingMode = enum { none, variable, parameter };

    source: []const u8,
    sink: *api.CaptureSink,
    capture_count: usize,
    source_cursor: usize = 0,
    expected: ?Scope = null,
    paren_depth: usize = 0,
    parameter_depth: ?usize = null,
    awaiting_parameters: bool = false,
    awaiting_return_type: bool = false,
    type_context: bool = false,
    import_active: bool = false,
    binding_mode: BindingMode = .none,
    bit_array_depth: usize = 0,
    bit_array_modifier: bool = false,
    import_names: [16][]const u8 = undefined,
    import_name_count: usize = 0,
    suppressed_until: usize = 0,

    fn run(parser: *Parser) api.HighlightError!void {
        var capture_index: usize = 0;
        while (capture_index < parser.capture_count) : (capture_index += 1) {
            const capture = parser.sink.captures()[capture_index];
            if (capture.span.start >= parser.source_cursor) {
                if (std.mem.indexOfScalar(u8, parser.source[parser.source_cursor..capture.span.start], '\n') != null and
                    parser.parameter_depth == null)
                {
                    parser.expected = null;
                    parser.type_context = false;
                    parser.import_active = false;
                    parser.binding_mode = .none;
                    parser.bit_array_modifier = false;
                }
                parser.source_cursor = capture.span.end;
            } else {
                parser.source_cursor = @max(parser.source_cursor, capture.span.end);
            }

            if (capture.span.start < parser.suppressed_until) {
                parser.empty(capture_index);
                continue;
            }

            switch (capture.scope) {
                .keyword => parser.observeKeyword(capture),
                .type, .builtin, .boolean, .constant => {},
                .variable, .property, .function, .label => try parser.refineWord(capture_index, capture),
                .operator => parser.observeOperator(capture),
                .punctuation => parser.observePunctuation(capture),
                else => {},
            }
        }
    }

    fn observeKeyword(parser: *Parser, capture: Capture) void {
        const word = parser.source[capture.span.start..capture.span.end];
        if (std.mem.eql(u8, word, "import")) {
            parser.expected = .namespace;
            parser.import_active = true;
        } else if (std.mem.eql(u8, word, "as") and parser.import_active) {
            parser.expected = .namespace;
        } else if (std.mem.eql(u8, word, "type")) {
            parser.expected = .type;
        } else if (std.mem.eql(u8, word, "fn")) {
            if (scanner.nextNonSpace(parser.source, capture.span.end) == '(') {
                parser.awaiting_parameters = true;
            } else {
                parser.expected = .function;
            }
        } else if (std.mem.eql(u8, word, "const")) {
            parser.expected = .constant;
        } else if (std.mem.eql(u8, word, "let")) {
            parser.binding_mode = .variable;
        } else if (std.mem.eql(u8, word, "use")) {
            parser.binding_mode = .parameter;
        }
    }

    fn refineWord(parser: *Parser, capture_index: usize, capture: Capture) api.HighlightError!void {
        const start = capture.span.start;
        const end = capture.span.end;
        const word = parser.source[start..end];

        if (parser.expected) |expected| {
            if (expected == .namespace) {
                const path_end = importPathEnd(parser.source, start);
                parser.rememberImportName(parser.source[start..path_end]);
                parser.empty(capture_index);
                parser.suppressed_until = path_end;
                try parser.sink.add(start, path_end, .namespace);
            } else {
                parser.setScope(capture_index, expected);
            }
            parser.expected = null;
            if (expected == .function) parser.awaiting_parameters = true;
            return;
        }

        const next = scanner.nextNonSpace(parser.source, end);
        const previous = scanner.previousNonSpace(parser.source, start);
        const scope: Scope = if (parser.bit_array_modifier)
            .attribute
        else if (parser.binding_mode != .none)
            if (std.ascii.isUpper(word[0])) .constructor else @as(Scope, switch (parser.binding_mode) {
                .variable => .variable,
                .parameter => .parameter,
                .none => unreachable,
            })
        else if (parser.type_context)
            .type
        else if (parser.bit_array_depth != 0 and next == ':')
            .variable
        else if (previous == '.' and start >= 2 and parser.source[start - 2] == '.')
            .variable
        else if (parser.parameter_depth != null and
            (next == ':' or previous == '(' or previous == ','))
            .parameter
        else if (next == ':' and parser.parameter_depth == null)
            .property
        else if (parser.isImportName(word))
            .namespace
        else if (previous == '.')
            if (next == '(') .function else .property
        else if (std.ascii.isUpper(word[0]))
            .constructor
        else if (next == '(')
            .function
        else
            .variable;
        parser.setScope(capture_index, scope);
        parser.bit_array_modifier = false;
    }

    fn observeOperator(parser: *Parser, capture: Capture) void {
        const operator = parser.source[capture.span.start..capture.span.end];
        if (std.mem.eql(u8, operator, "<<")) {
            parser.bit_array_depth += 1;
        } else if (std.mem.eql(u8, operator, ">>")) {
            parser.bit_array_depth -|= 1;
            parser.bit_array_modifier = false;
        } else if (operator[0] == ':' and parser.bit_array_depth != 0) {
            parser.bit_array_modifier = true;
        } else if (operator[0] == ':' or (std.mem.eql(u8, operator, "->") and parser.awaiting_return_type)) {
            parser.type_context = true;
            parser.awaiting_return_type = false;
        } else if (operator[0] == '=' or std.mem.eql(u8, operator, "<-")) {
            parser.type_context = false;
            parser.binding_mode = .none;
        }
    }

    fn observePunctuation(parser: *Parser, capture: Capture) void {
        switch (parser.source[capture.span.start]) {
            '(' => {
                parser.paren_depth += 1;
                if (parser.awaiting_parameters) {
                    parser.parameter_depth = parser.paren_depth;
                    parser.awaiting_parameters = false;
                }
            },
            ')' => {
                if (parser.parameter_depth == parser.paren_depth) {
                    parser.parameter_depth = null;
                    parser.awaiting_return_type = true;
                }
                parser.paren_depth -|= 1;
                parser.type_context = false;
            },
            '{' => {
                parser.awaiting_return_type = false;
                parser.type_context = false;
            },
            ',' => parser.type_context = false,
            ';' => {
                parser.expected = null;
                parser.type_context = false;
                parser.import_active = false;
                parser.binding_mode = .none;
            },
            else => {},
        }
    }

    fn setScope(parser: *Parser, capture_index: usize, scope: Scope) void {
        parser.sink.mutableCaptures()[capture_index].scope = scope;
    }

    fn empty(parser: *Parser, capture_index: usize) void {
        const start = parser.sink.captures()[capture_index].span.start;
        parser.sink.mutableCaptures()[capture_index].span.end = start;
    }

    fn rememberImportName(parser: *Parser, path: []const u8) void {
        if (parser.import_name_count == parser.import_names.len) return;
        const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse 0;
        const dot = std.mem.lastIndexOfScalar(u8, path, '.') orelse 0;
        const separator = @max(slash, dot);
        const name = if (separator == 0) path else path[separator + 1 ..];
        parser.import_names[parser.import_name_count] = name;
        parser.import_name_count += 1;
    }

    fn isImportName(parser: *const Parser, word: []const u8) bool {
        for (parser.import_names[0..parser.import_name_count]) |name| {
            if (std.mem.eql(u8, name, word)) return true;
        }
        return false;
    }
};

fn importPathEnd(source: []const u8, start: usize) usize {
    var end = scanner.identifierEnd(source, start, .ascii);
    while (end + 1 < source.len and (source[end] == '/' or source[end] == '.') and
        scanner.isAsciiIdentifierStart(source[end + 1]))
    {
        end = scanner.identifierEnd(source, end + 1, .ascii);
    }
    return end;
}
