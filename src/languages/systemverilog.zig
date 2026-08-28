const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const scanners = @import("roadmap_scanners.zig");
const scanner = @import("scanner_support.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "systemverilog",
    .display_name = "SystemVerilog",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try scanners.highlight(source, sink, .systemverilog);
    var parser: Parser = .{ .source = source, .sink = sink };
    defer parser.deinit();
    try parser.run();
}

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    index: usize = 0,
    paren_depth: usize = 0,
    brace_depth: usize = 0,
    expected: ?Scope = null,
    declaration_scope: ?Scope = null,
    declaration_ready: bool = false,
    function_declaration: bool = false,
    pending_function: bool = false,
    function_parameters: ?usize = null,
    module_header: bool = false,
    typedef_declaration: bool = false,
    pending_enum: bool = false,
    enum_depth: ?usize = null,
    known_types: std.ArrayList([]const u8) = .empty,

    fn deinit(parser: *Parser) void {
        parser.known_types.deinit(parser.sink.allocator);
    }

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (std.mem.startsWith(u8, parser.source[parser.index..], "//")) {
                parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len);
                continue;
            }
            if (std.mem.startsWith(u8, parser.source[parser.index..], "/*")) {
                parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*/")) |end| end + 2 else parser.source.len;
                continue;
            }
            if (std.mem.startsWith(u8, parser.source[parser.index..], "(*")) {
                try parser.scanAttribute();
                continue;
            }
            switch (parser.source[parser.index]) {
                '"' => parser.index = scanner.quotedEnd(parser.source, parser.index, '"', true),
                '`' => try parser.scanDirective(),
                '$' => try parser.scanSystemIdentifier(),
                '\\' => try parser.scanEscapedIdentifier(),
                '0'...'9' => try parser.scanNumber(),
                '(' => {
                    parser.paren_depth += 1;
                    if (parser.pending_function) {
                        parser.function_parameters = parser.paren_depth;
                        parser.pending_function = false;
                    }
                    parser.index += 1;
                },
                ')' => {
                    if (parser.function_parameters == parser.paren_depth) parser.function_parameters = null;
                    parser.paren_depth -|= 1;
                    parser.index += 1;
                },
                '{' => {
                    parser.brace_depth += 1;
                    if (parser.pending_enum) {
                        parser.enum_depth = parser.brace_depth;
                        parser.pending_enum = false;
                    }
                    parser.index += 1;
                },
                '}' => {
                    if (parser.enum_depth == parser.brace_depth) parser.enum_depth = null;
                    parser.brace_depth -|= 1;
                    parser.index += 1;
                },
                ',' => {
                    parser.declaration_ready = parser.declaration_scope != null;
                    parser.index += 1;
                },
                ';' => {
                    parser.resetDeclaration();
                    parser.module_header = false;
                    parser.index += 1;
                },
                '=' => {
                    parser.declaration_ready = false;
                    parser.index += 1;
                },
                'a'...'z', 'A'...'Z', '_' => try parser.scanIdentifier(),
                else => parser.index += scanner.validUtf8Length(parser.source[parser.index..]),
            }
        }
    }

    fn scanIdentifier(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        const word = parser.source[start..parser.index];
        const next = scanner.nextNonSpace(parser.source, parser.index);

        if (parser.expected) |scope| {
            try parser.sink.add(start, parser.index, scope);
            if (scope == .type) {
                try parser.rememberType(word);
                parser.module_header = true;
            }
            parser.expected = null;
            return;
        }
        if (wordIs(word, &.{ "module", "interface", "program", "class" })) {
            parser.expected = .type;
            return;
        }
        if (std.mem.eql(u8, word, "package")) {
            parser.expected = .namespace;
            return;
        }
        if (std.mem.eql(u8, word, "import")) {
            parser.expected = .namespace;
            return;
        }
        if (wordIs(word, &.{ "function", "task" })) {
            parser.function_declaration = true;
            return;
        }
        if (std.mem.eql(u8, word, "typedef")) {
            parser.typedef_declaration = true;
            return;
        }
        if (std.mem.eql(u8, word, "enum")) {
            parser.pending_enum = true;
            return;
        }
        if (wordIs(word, &.{ "input", "output", "inout", "ref" })) {
            parser.declaration_scope = .parameter;
            return;
        }
        if (wordIs(word, &.{ "parameter", "localparam" })) {
            parser.declaration_scope = .constant;
            return;
        }
        if (isTypeQualifier(word)) return;
        if (parser.isKnownType(word)) {
            try parser.sink.add(start, parser.index, .type);
            parser.declaration_ready = true;
            return;
        }
        if (parser.isBuiltinType(word)) {
            parser.declaration_ready = true;
            return;
        }
        if (isKeyword(word)) return;

        if (parser.function_declaration) {
            try parser.sink.add(start, parser.index, .function);
            parser.function_declaration = false;
            parser.pending_function = true;
        } else if (parser.typedef_declaration and next == ';') {
            try parser.sink.add(start, parser.index, .type);
            try parser.rememberType(word);
            parser.typedef_declaration = false;
        } else if (parser.enum_depth == parser.brace_depth) {
            try parser.sink.add(start, parser.index, .constant);
        } else if (parser.declaration_ready) {
            const scope: Scope = parser.declaration_scope orelse if (parser.module_header or parser.function_parameters != null) .parameter else .variable;
            try parser.sink.add(start, parser.index, scope);
            parser.declaration_ready = false;
        } else if (scanner.previousNonSpace(parser.source, start) == '.') {
            try parser.sink.add(start, parser.index, .property);
        } else if (next == '(') {
            try parser.sink.add(start, parser.index, .function);
        } else if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .type);
            parser.declaration_ready = true;
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn scanDirective(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        }
        try parser.sink.add(start, parser.index, .macro);
        const directive = parser.source[start + 1 .. parser.index];
        if (!std.mem.eql(u8, directive, "define")) return;
        while (parser.index < parser.source.len and (parser.source[parser.index] == ' ' or parser.source[parser.index] == '\t')) parser.index += 1;
        if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            const name = parser.index;
            parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
            try parser.sink.add(name, parser.index, .macro);
        }
    }

    fn scanSystemIdentifier(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        if (parser.index < parser.source.len and scanner.isAsciiIdentifierStart(parser.source[parser.index])) {
            parser.index = scanner.identifierEnd(parser.source, parser.index, .ascii);
        }
        try parser.sink.add(start, parser.index, .function);
    }

    fn scanEscapedIdentifier(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and !std.ascii.isWhitespace(parser.source[parser.index])) parser.index += 1;
        try parser.sink.add(start, parser.index, .variable);
    }

    fn scanNumber(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += 1;
        while (parser.index < parser.source.len and
            (std.ascii.isAlphanumeric(parser.source[parser.index]) or
                std.mem.indexOfScalar(u8, "_'?xXzZ.", parser.source[parser.index]) != null)) parser.index += 1;
        try parser.sink.add(start, parser.index, .number);
    }

    fn scanAttribute(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index = if (std.mem.indexOfPos(u8, parser.source, parser.index + 2, "*)")) |end| end + 2 else parser.source.len;
        try parser.sink.add(start, parser.index, .attribute);
    }

    fn resetDeclaration(parser: *Parser) void {
        parser.expected = null;
        parser.declaration_scope = null;
        parser.declaration_ready = false;
        parser.function_declaration = false;
        parser.pending_function = false;
        parser.typedef_declaration = false;
    }

    fn rememberType(parser: *Parser, word: []const u8) api.HighlightError!void {
        if (!parser.isKnownType(word)) try parser.known_types.append(parser.sink.allocator, word);
    }

    fn isKnownType(parser: Parser, word: []const u8) bool {
        for (parser.known_types.items) |known| if (std.mem.eql(u8, known, word)) return true;
        return false;
    }

    fn isBuiltinType(parser: Parser, word: []const u8) bool {
        _ = parser;
        return wordIs(word, scanners.config(.systemverilog).types);
    }
};

fn isTypeQualifier(word: []const u8) bool {
    return wordIs(word, &.{ "automatic", "const", "packed", "signed", "static", "unsigned", "var" });
}

fn isKeyword(word: []const u8) bool {
    return wordIs(word, scanners.config(.systemverilog).keywords);
}

const wordIs = scanner.wordIs;
