//! Tolerant Bash syntax for contextual highlighting.
//!
//! This parser recognizes shell structure needed by the highlighter while
//! retaining original byte ranges and useful partial trees for incomplete
//! input. It is not a shell expander, executor, or validator.

const std = @import("std");
const syntax = @import("../syntax.zig");

pub const TokenTag = enum {
    eof,
    invalid,
    newline,
    word,
    number,
    keyword,
    comment,
    string,
    expandable_string,
    variable,
    command_substitution,
    arithmetic_substitution,
    escape,
    operator,
    punctuation,
    assignment,
    heredoc_label,
    heredoc_body,
};

pub const NodeTag = enum {
    root,
    simple_command,
    command_name,
    argument,
    option,
    assignment,
    redirection,
    redirection_target,
    function_definition,
    function_name,
    loop_variable,
};

pub const DiagnosticTag = enum {
    expected_function_name,
    expected_redirection_target,
    unterminated_string,
    unterminated_command_substitution,
    unterminated_arithmetic_substitution,
    unterminated_heredoc,
};

pub const Syntax = syntax.Model(TokenTag, NodeTag, DiagnosticTag);
pub const Tree = Syntax.Tree;
pub const ParseError = syntax.BuildError;

pub fn parse(allocator: std.mem.Allocator, source: []const u8) ParseError!Tree {
    var builder = try Syntax.Builder.init(allocator, source.len);
    defer builder.deinit();

    try tokenize(source, &builder);

    var parser: Parser = .{
        .source = source,
        .builder = &builder,
        .cursor = .init(builder.tokens.items),
    };
    try parser.parseRoot();

    return builder.finish(source);
}

const Heredoc = struct {
    delimiter: []const u8,
    label_start: usize,
    strip_tabs: bool,
};

fn tokenize(source: []const u8, builder: *Syntax.Builder) ParseError!void {
    var tokenizer: Tokenizer = .{
        .source = source,
        .builder = builder,
    };
    defer tokenizer.pending_heredocs.deinit(builder.allocator);
    try tokenizer.run();
}

const Tokenizer = struct {
    source: []const u8,
    builder: *Syntax.Builder,
    index: usize = 0,
    line_start: usize = 0,
    pending_heredocs: std.ArrayList(Heredoc) = .empty,

    fn run(tokenizer: *Tokenizer) ParseError!void {
        while (tokenizer.index < tokenizer.source.len) {
            if (tokenizer.index == tokenizer.line_start and tokenizer.pending_heredocs.items.len > 0) {
                try tokenizer.scanHeredocLine();
                continue;
            }

            const byte = tokenizer.source[tokenizer.index];
            switch (byte) {
                '\n' => {
                    try tokenizer.capture(.newline, tokenizer.index, tokenizer.index + 1);
                    tokenizer.index += 1;
                    tokenizer.line_start = tokenizer.index;
                },
                ' ', '\t', '\r' => tokenizer.index += 1,
                '\'' => try tokenizer.scanQuoted(.string, '\'', tokenizer.index, tokenizer.index + 1),
                '"' => try tokenizer.scanQuoted(.expandable_string, '"', tokenizer.index, tokenizer.index + 1),
                '`' => try tokenizer.scanBackticks(),
                '$' => try tokenizer.scanDollar(),
                '\\' => {
                    const end = escapeEnd(tokenizer.source, tokenizer.index, tokenizer.source.len);
                    try tokenizer.capture(.escape, tokenizer.index, end);
                    tokenizer.index = end;
                },
                '#' => if (tokenizer.startsComment()) {
                    try tokenizer.scanComment();
                } else {
                    try tokenizer.scanWord();
                },
                '<' => if (tokenizer.startsWith("<<")) {
                    try tokenizer.scanHeredocStart();
                } else {
                    try tokenizer.scanOperator();
                },
                '|', '&', ';', '>', '(', ')' => try tokenizer.scanOperator(),
                '[' => if (tokenizer.startsWith("[[")) {
                    try tokenizer.capture(.punctuation, tokenizer.index, tokenizer.index + 2);
                    tokenizer.index += 2;
                } else {
                    try tokenizer.capture(.word, tokenizer.index, tokenizer.index + 1);
                    tokenizer.index += 1;
                },
                ']' => if (tokenizer.startsWith("]]")) {
                    try tokenizer.capture(.punctuation, tokenizer.index, tokenizer.index + 2);
                    tokenizer.index += 2;
                } else {
                    try tokenizer.captureByte(.punctuation);
                },
                '{', '}' => try tokenizer.captureByte(.punctuation),
                '0'...'9' => try tokenizer.scanNumber(),
                else => if (byte >= 0x80) {
                    if (validUtf8SequenceLength(tokenizer.source[tokenizer.index..])) |len| {
                        tokenizer.index += len;
                    } else {
                        try tokenizer.captureByte(.invalid);
                    }
                } else {
                    try tokenizer.scanWord();
                },
            }
        }

        for (tokenizer.pending_heredocs.items) |heredoc| {
            try tokenizer.builder.addDiagnostic(.unterminated_heredoc, heredoc.label_start);
        }
        _ = try tokenizer.builder.addToken(.eof, tokenizer.source.len, tokenizer.source.len);
    }

    fn startsWith(tokenizer: Tokenizer, text: []const u8) bool {
        return std.mem.startsWith(u8, tokenizer.source[tokenizer.index..], text);
    }

    fn capture(tokenizer: *Tokenizer, tag: TokenTag, start: usize, end: usize) ParseError!void {
        _ = try tokenizer.builder.addToken(tag, start, end);
    }

    fn captureByte(tokenizer: *Tokenizer, tag: TokenTag) ParseError!void {
        try tokenizer.capture(tag, tokenizer.index, tokenizer.index + 1);
        tokenizer.index += 1;
    }

    fn scanComment(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index = std.mem.indexOfScalarPos(u8, tokenizer.source, start, '\n') orelse tokenizer.source.len;
        try tokenizer.capture(.comment, start, tokenizer.index);
    }

    fn scanQuoted(
        tokenizer: *Tokenizer,
        tag: TokenTag,
        quote: u8,
        start: usize,
        content_start: usize,
    ) ParseError!void {
        tokenizer.index = content_start;
        var terminated = false;
        while (tokenizer.index < tokenizer.source.len) {
            const backslash_escapes = tag == .expandable_string or
                (start + 1 < tokenizer.source.len and tokenizer.source[start] == '$');
            if (backslash_escapes and tokenizer.source[tokenizer.index] == '\\') {
                tokenizer.index = @min(tokenizer.index + 2, tokenizer.source.len);
                continue;
            }
            if (tag == .expandable_string and tokenizer.source[tokenizer.index] == '$') {
                tokenizer.index = dollarEnd(tokenizer.source, tokenizer.index);
                continue;
            }
            if (tag == .expandable_string and tokenizer.source[tokenizer.index] == '`') {
                tokenizer.index = commandSubstitutionEnd(tokenizer.source, tokenizer.index, '`').end;
                continue;
            }
            const byte = tokenizer.source[tokenizer.index];
            tokenizer.index += 1;
            if (byte == quote) {
                terminated = true;
                break;
            }
        }
        if (!terminated) try tokenizer.builder.addDiagnostic(.unterminated_string, start);
        try tokenizer.capture(tag, start, tokenizer.index);
    }

    fn scanBackticks(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        const result = commandSubstitutionEnd(tokenizer.source, start, '`');
        tokenizer.index = result.end;
        if (!result.terminated) {
            try tokenizer.builder.addDiagnostic(.unterminated_command_substitution, start);
        }
        try tokenizer.capture(.command_substitution, start, tokenizer.index);
    }

    fn scanDollar(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        if (start + 1 >= tokenizer.source.len) {
            tokenizer.index += 1;
            try tokenizer.capture(.word, start, tokenizer.index);
            return;
        }
        const next = tokenizer.source[start + 1];

        if (next == '\'' or next == '"') {
            const tag: TokenTag = if (next == '"') .expandable_string else .string;
            try tokenizer.scanQuoted(tag, next, start, start + 2);
            return;
        }
        if (next == '{') {
            const result = balancedEnd(tokenizer.source, start + 1, '{', '}');
            tokenizer.index = result.end;
            try tokenizer.capture(.variable, start, tokenizer.index);
            return;
        }
        if (next == '(') {
            if (start + 2 < tokenizer.source.len and tokenizer.source[start + 2] == '(') {
                const result = arithmeticEnd(tokenizer.source, start + 3);
                tokenizer.index = result.end;
                if (!result.terminated) {
                    try tokenizer.builder.addDiagnostic(.unterminated_arithmetic_substitution, start);
                }
                try tokenizer.capture(.arithmetic_substitution, start, tokenizer.index);
            } else {
                const result = commandSubstitutionEnd(tokenizer.source, start + 1, ')');
                tokenizer.index = result.end;
                if (!result.terminated) {
                    try tokenizer.builder.addDiagnostic(.unterminated_command_substitution, start);
                }
                try tokenizer.capture(.command_substitution, start, tokenizer.index);
            }
            return;
        }
        if (isIdentifierStart(next)) {
            tokenizer.index = start + 2;
            while (tokenizer.index < tokenizer.source.len and isIdentifierContinue(tokenizer.source[tokenizer.index])) {
                tokenizer.index += 1;
            }
            try tokenizer.capture(.variable, start, tokenizer.index);
            return;
        }
        if (std.ascii.isDigit(next) or std.mem.indexOfScalar(u8, "?*$#@!-_", next) != null) {
            tokenizer.index = start + 2;
            try tokenizer.capture(.variable, start, tokenizer.index);
            return;
        }

        tokenizer.index += 1;
        try tokenizer.capture(.word, start, tokenizer.index);
    }

    fn scanNumber(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += 1;
        while (tokenizer.index < tokenizer.source.len and
            (std.ascii.isDigit(tokenizer.source[tokenizer.index]) or tokenizer.source[tokenizer.index] == '_'))
        {
            tokenizer.index += 1;
        }
        if (tokenizer.index < tokenizer.source.len and !isWordBoundary(tokenizer.source[tokenizer.index])) {
            while (tokenizer.index < tokenizer.source.len and !isWordBoundary(tokenizer.source[tokenizer.index])) {
                tokenizer.index += 1;
            }
            try tokenizer.capture(.word, start, tokenizer.index);
        } else {
            try tokenizer.capture(.number, start, tokenizer.index);
        }
    }

    fn scanWord(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        while (tokenizer.index < tokenizer.source.len and !isWordBoundary(tokenizer.source[tokenizer.index])) {
            tokenizer.index += 1;
        }
        if (tokenizer.index == start) {
            tokenizer.index += 1;
            try tokenizer.capture(.invalid, start, tokenizer.index);
            return;
        }

        const word = tokenizer.source[start..tokenizer.index];
        const tag: TokenTag = if (assignmentOperator(word) != null)
            .assignment
        else if (isKeyword(word))
            .keyword
        else
            .word;
        try tokenizer.capture(tag, start, tokenizer.index);
    }

    fn scanOperator(tokenizer: *Tokenizer) ParseError!void {
        const start = tokenizer.index;
        tokenizer.index += operatorLength(tokenizer.source[start..]);
        try tokenizer.capture(.operator, start, tokenizer.index);
    }

    fn scanHeredocStart(tokenizer: *Tokenizer) ParseError!void {
        const operator_start = tokenizer.index;
        tokenizer.index += 2;
        if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '<') {
            tokenizer.index += 1;
            try tokenizer.capture(.operator, operator_start, tokenizer.index);
            return;
        }

        var strip_tabs = false;
        if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == '-') {
            strip_tabs = true;
            tokenizer.index += 1;
        }
        try tokenizer.capture(.operator, operator_start, tokenizer.index);
        while (tokenizer.index < tokenizer.source.len and
            (tokenizer.source[tokenizer.index] == ' ' or tokenizer.source[tokenizer.index] == '\t'))
        {
            tokenizer.index += 1;
        }
        if (tokenizer.index >= tokenizer.source.len or tokenizer.source[tokenizer.index] == '\n') return;

        const label_start = tokenizer.index;
        var delimiter_start = label_start;
        var delimiter_end: usize = undefined;
        if (tokenizer.source[tokenizer.index] == '\'' or tokenizer.source[tokenizer.index] == '"') {
            const quote = tokenizer.source[tokenizer.index];
            delimiter_start += 1;
            tokenizer.index += 1;
            while (tokenizer.index < tokenizer.source.len and
                tokenizer.source[tokenizer.index] != quote and tokenizer.source[tokenizer.index] != '\n')
            {
                tokenizer.index += 1;
            }
            delimiter_end = tokenizer.index;
            if (tokenizer.index < tokenizer.source.len and tokenizer.source[tokenizer.index] == quote) {
                tokenizer.index += 1;
            }
        } else {
            while (tokenizer.index < tokenizer.source.len and
                !std.ascii.isWhitespace(tokenizer.source[tokenizer.index]) and
                std.mem.indexOfScalar(u8, ";|&<>()", tokenizer.source[tokenizer.index]) == null)
            {
                tokenizer.index += 1;
            }
            delimiter_end = tokenizer.index;
        }
        if (delimiter_end == delimiter_start) return;

        try tokenizer.capture(.heredoc_label, label_start, tokenizer.index);
        try tokenizer.pending_heredocs.append(tokenizer.builder.allocator, .{
            .delimiter = tokenizer.source[delimiter_start..delimiter_end],
            .label_start = label_start,
            .strip_tabs = strip_tabs,
        });
    }

    fn scanHeredocLine(tokenizer: *Tokenizer) ParseError!void {
        const heredoc = tokenizer.pending_heredocs.items[0];
        const content_end = std.mem.indexOfScalarPos(u8, tokenizer.source, tokenizer.index, '\n') orelse tokenizer.source.len;
        var comparison_start = tokenizer.index;
        if (heredoc.strip_tabs) {
            while (comparison_start < content_end and tokenizer.source[comparison_start] == '\t') {
                comparison_start += 1;
            }
        }
        const comparison_end = if (content_end > comparison_start and
            tokenizer.source[content_end - 1] == '\r') content_end - 1 else content_end;
        const line_end = if (content_end < tokenizer.source.len) content_end + 1 else content_end;

        if (std.mem.eql(u8, tokenizer.source[comparison_start..comparison_end], heredoc.delimiter)) {
            try tokenizer.capture(.heredoc_label, comparison_start, comparison_end);
            _ = tokenizer.pending_heredocs.orderedRemove(0);
        } else {
            try tokenizer.capture(.heredoc_body, tokenizer.index, line_end);
        }
        tokenizer.index = line_end;
        tokenizer.line_start = line_end;
    }

    fn startsComment(tokenizer: Tokenizer) bool {
        if (tokenizer.index == tokenizer.line_start) return true;
        const previous = tokenizer.source[tokenizer.index - 1];
        return std.ascii.isWhitespace(previous) or
            std.mem.indexOfScalar(u8, ";|&(){}", previous) != null;
    }
};

fn validUtf8SequenceLength(source: []const u8) ?usize {
    const len = std.unicode.utf8ByteSequenceLength(source[0]) catch return null;
    if (len > source.len) return null;
    _ = std.unicode.utf8Decode(source[0..len]) catch return null;
    return len;
}

fn escapeEnd(source: []const u8, start: usize, limit: usize) usize {
    const escaped_start = start + 1;
    if (escaped_start >= limit) return limit;
    const len = validUtf8SequenceLength(source[escaped_start..limit]) orelse 1;
    return escaped_start + len;
}

const WordRole = enum {
    command,
    argument,
    function_name,
    loop_variable,
    redirection_target,
};

const Parser = struct {
    source: []const u8,
    builder: *Syntax.Builder,
    cursor: Syntax.Cursor,
    role: WordRole = .command,
    redirection_return_role: WordRole = .argument,
    function_keyword: ?syntax.TokenIndex = null,
    redirection_operator: ?syntax.TokenIndex = null,
    simple_first: ?syntax.TokenIndex = null,
    simple_main: ?syntax.TokenIndex = null,

    fn parseRoot(parser: *Parser) ParseError!void {
        while (parser.cursor.peekTag(0)) |tag| {
            if (tag == .eof) break;
            const token_index: syntax.TokenIndex = @intCast(parser.cursor.index);
            switch (tag) {
                .newline => {
                    try parser.finishSimpleCommand(token_index);
                    parser.resetCommand();
                },
                .keyword => try parser.parseKeyword(token_index),
                .assignment => try parser.parseAssignment(token_index),
                .operator => try parser.parseOperator(token_index),
                .punctuation => try parser.parsePunctuation(token_index),
                .word,
                .number,
                .string,
                .expandable_string,
                .variable,
                .command_substitution,
                .arithmetic_substitution,
                .escape,
                => try parser.parseWordComponent(token_index),
                .heredoc_label => try parser.parseHeredocLabel(token_index),
                .invalid,
                .comment,
                .heredoc_body,
                .eof,
                => {},
            }
            _ = parser.cursor.advance();
        }

        try parser.finishSimpleCommand(parser.eofIndex());

        if (parser.role == .redirection_target) {
            if (parser.redirection_operator) |operator| {
                try parser.builder.addDiagnostic(.expected_redirection_target, parser.tokenEnd(operator));
            }
        }
        if (parser.role == .function_name) {
            if (parser.function_keyword) |keyword| {
                try parser.builder.addDiagnostic(.expected_function_name, parser.tokenEnd(keyword));
            }
        }

        const token_count: syntax.TokenIndex = @intCast(parser.builder.tokens.items.len);
        _ = try parser.builder.addNode(.root, 0, token_count, 0);
    }

    fn parseKeyword(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        const word = parser.tokenText(token_index);
        if (std.mem.eql(u8, word, "function")) {
            parser.role = .function_name;
            parser.function_keyword = token_index;
        } else if (std.mem.eql(u8, word, "for") or std.mem.eql(u8, word, "select")) {
            parser.role = .loop_variable;
        } else if (commandFollowsKeyword(word)) {
            parser.role = .command;
        } else {
            parser.role = .argument;
        }
    }

    fn parseAssignment(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        if (parser.role == .command) parser.beginSimpleCommand(token_index, token_index);
        const last = parser.shellWordEnd(token_index);
        _ = try parser.builder.addNode(.assignment, token_index, last, token_index);
        parser.cursor.index = last - 1;
    }

    fn parseOperator(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        const operator = parser.tokenText(token_index);
        if (isControlOperator(operator)) {
            try parser.finishSimpleCommand(token_index);
            parser.resetCommand();
        } else if (isRedirectionOperator(operator)) {
            if (parser.simple_first == null) parser.beginSimpleCommand(token_index, token_index);
            parser.redirection_return_role = parser.role;
            parser.role = .redirection_target;
            parser.redirection_operator = token_index;
        }
    }

    fn parsePunctuation(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        const punctuation = parser.tokenText(token_index);
        if (std.mem.eql(u8, punctuation, "{")) {
            try parser.finishSimpleCommand(token_index);
            parser.resetCommand();
        } else if (std.mem.eql(u8, punctuation, "}")) {
            try parser.finishSimpleCommand(token_index);
            parser.role = .argument;
        } else if (std.mem.eql(u8, punctuation, "[[")) {
            parser.role = .argument;
        }
    }

    fn parseWordComponent(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        if (parser.role == .redirection_target) {
            try parser.addRedirectionTarget(token_index);
            return;
        }

        if (parser.role == .function_name) {
            if (parser.function_keyword == null) {
                parser.role = .argument;
                return parser.parseWordComponent(token_index);
            }
            if (parser.tokenTag(token_index) == .word) {
                const last = parser.shellWordEnd(token_index);
                _ = try parser.builder.addNode(.function_name, token_index, last, token_index);
                _ = try parser.builder.addNode(
                    .function_definition,
                    parser.function_keyword.?,
                    last,
                    token_index,
                );
                parser.cursor.index = last - 1;
                parser.role = .argument;
                parser.function_keyword = null;
                return;
            }
            return;
        }

        if (parser.role == .loop_variable) {
            if (parser.tokenTag(token_index) == .word) {
                _ = try parser.builder.addNode(.loop_variable, token_index, token_index + 1, token_index);
            }
            parser.role = .argument;
            return;
        }

        if (parser.role == .command) {
            if (parser.isFileDescriptorBeforeRedirection(token_index)) return;
            if (parser.tokenTag(token_index) == .word) {
                if (parser.looksLikeFunctionDefinition(token_index)) {
                    _ = try parser.builder.addNode(.function_name, token_index, token_index + 1, token_index);
                    const close = parser.nextSignificant(parser.nextSignificant(token_index + 1) + 1);
                    _ = try parser.builder.addNode(.function_definition, token_index, close + 1, token_index);
                } else {
                    const last = parser.shellWordEnd(token_index);
                    _ = try parser.builder.addNode(.command_name, token_index, last, token_index);
                    parser.beginSimpleCommand(token_index, token_index);
                    parser.cursor.index = last - 1;
                }
            } else {
                parser.beginSimpleCommand(token_index, token_index);
            }
            parser.role = .argument;
            return;
        }

        const last = parser.shellWordEnd(token_index);
        _ = try parser.builder.addNode(.argument, token_index, last, token_index);
        if (parser.tokenTag(token_index) == .word and parser.tokenText(token_index).len > 1 and
            parser.tokenText(token_index)[0] == '-')
        {
            _ = try parser.builder.addNode(.option, token_index, last, token_index);
        }
        parser.cursor.index = last - 1;
    }

    fn parseHeredocLabel(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        if (parser.role == .redirection_target) try parser.addRedirectionTarget(token_index);
    }

    fn addRedirectionTarget(parser: *Parser, token_index: syntax.TokenIndex) ParseError!void {
        const operator = parser.redirection_operator orelse {
            parser.role = .argument;
            return parser.parseWordComponent(token_index);
        };
        const last = parser.shellWordEnd(token_index);
        _ = try parser.builder.addNode(.redirection_target, token_index, last, token_index);
        _ = try parser.builder.addNode(
            .redirection,
            operator,
            last,
            operator,
        );
        parser.cursor.index = last - 1;
        parser.role = parser.redirection_return_role;
        parser.redirection_operator = null;
    }

    fn resetCommand(parser: *Parser) void {
        parser.role = .command;
        parser.redirection_return_role = .argument;
        parser.redirection_operator = null;
        parser.function_keyword = null;
        parser.simple_first = null;
        parser.simple_main = null;
    }

    fn beginSimpleCommand(
        parser: *Parser,
        first: syntax.TokenIndex,
        main: syntax.TokenIndex,
    ) void {
        if (parser.simple_first == null) parser.simple_first = first;
        parser.simple_main = main;
    }

    fn finishSimpleCommand(parser: *Parser, last: syntax.TokenIndex) ParseError!void {
        const first = parser.simple_first orelse return;
        const main = parser.simple_main.?;
        if (last > first) {
            _ = try parser.builder.addNode(.simple_command, first, last, main);
        }
        parser.simple_first = null;
        parser.simple_main = null;
    }

    fn shellWordEnd(parser: Parser, first: syntax.TokenIndex) syntax.TokenIndex {
        var index: usize = first + 1;
        var previous_end = parser.builder.tokens.items[first].end;
        while (index < parser.builder.tokens.items.len) : (index += 1) {
            const token = parser.builder.tokens.items[index];
            if (token.start != previous_end or !isWordComponent(token.tag)) break;
            previous_end = token.end;
        }
        return @intCast(index);
    }

    fn looksLikeFunctionDefinition(parser: Parser, name: syntax.TokenIndex) bool {
        const open = parser.nextSignificant(name + 1);
        if (parser.tokenTag(open) != .operator or !std.mem.eql(u8, parser.tokenText(open), "(")) return false;
        const close = parser.nextSignificant(open + 1);
        return parser.tokenTag(close) == .operator and std.mem.eql(u8, parser.tokenText(close), ")");
    }

    fn isFileDescriptorBeforeRedirection(parser: Parser, token_index: syntax.TokenIndex) bool {
        if (parser.tokenTag(token_index) != .number) return false;
        const next = token_index + 1;
        if (next >= parser.builder.tokens.items.len) return false;
        return parser.builder.tokens.items[token_index].end == parser.builder.tokens.items[next].start and
            parser.tokenTag(next) == .operator and isRedirectionOperator(parser.tokenText(next));
    }

    fn nextSignificant(parser: Parser, first: syntax.TokenIndex) syntax.TokenIndex {
        var index: usize = first;
        while (index < parser.builder.tokens.items.len and parser.tokenTag(@intCast(index)) == .comment) {
            index += 1;
        }
        return @intCast(@min(index, parser.builder.tokens.items.len - 1));
    }

    fn tokenTag(parser: Parser, token_index: syntax.TokenIndex) TokenTag {
        return parser.builder.tokens.items[token_index].tag;
    }

    fn tokenText(parser: Parser, token_index: syntax.TokenIndex) []const u8 {
        return parser.builder.tokens.items[token_index].slice(parser.source);
    }

    fn tokenEnd(parser: Parser, token_index: syntax.TokenIndex) usize {
        return parser.builder.tokens.items[token_index].end;
    }

    fn eofIndex(parser: Parser) syntax.TokenIndex {
        return @intCast(parser.builder.tokens.items.len - 1);
    }
};

const EndResult = struct {
    end: usize,
    terminated: bool,
};

fn balancedEnd(source: []const u8, open_index: usize, open: u8, close: u8) EndResult {
    var depth: usize = 1;
    var cursor = open_index + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '\\') {
            cursor = @min(cursor + 1, source.len);
            continue;
        }
        if (source[cursor] == '\'' or source[cursor] == '"' or source[cursor] == '`') {
            cursor = quotedEnd(source, cursor, source[cursor]) - 1;
            continue;
        }
        if (source[cursor] == open) depth += 1;
        if (source[cursor] == close) {
            depth -= 1;
            if (depth == 0) return .{ .end = cursor + 1, .terminated = true };
        }
    }
    return .{ .end = source.len, .terminated = false };
}

fn quotedEnd(source: []const u8, start: usize, quote: u8) usize {
    var cursor = start + 1;
    while (cursor < source.len) : (cursor += 1) {
        if (quote != '\'' and source[cursor] == '\\') {
            cursor = @min(cursor + 1, source.len);
            continue;
        }
        if (source[cursor] == quote) return cursor + 1;
    }
    return source.len;
}

fn commandSubstitutionEnd(source: []const u8, open_index: usize, close: u8) EndResult {
    if (close == '`') {
        var cursor = open_index + 1;
        while (cursor < source.len) : (cursor += 1) {
            if (source[cursor] == '\\') {
                cursor = @min(cursor + 1, source.len);
                continue;
            }
            if (source[cursor] == '`') return .{ .end = cursor + 1, .terminated = true };
        }
        return .{ .end = source.len, .terminated = false };
    }
    return balancedEnd(source, open_index, '(', ')');
}

fn arithmeticEnd(source: []const u8, start: usize) EndResult {
    var depth: usize = 1;
    var cursor = start;
    while (cursor < source.len) : (cursor += 1) {
        if (source[cursor] == '(') depth += 1;
        if (source[cursor] == ')') {
            if (depth == 1 and cursor + 1 < source.len and source[cursor + 1] == ')') {
                return .{ .end = cursor + 2, .terminated = true };
            }
            depth -= 1;
        }
    }
    return .{ .end = source.len, .terminated = false };
}

fn dollarEnd(source: []const u8, start: usize) usize {
    if (start + 1 >= source.len) return start + 1;
    const next = source[start + 1];
    if (next == '{') return balancedEnd(source, start + 1, '{', '}').end;
    if (next == '(') {
        if (start + 2 < source.len and source[start + 2] == '(') {
            return arithmeticEnd(source, start + 3).end;
        }
        return commandSubstitutionEnd(source, start + 1, ')').end;
    }
    if (isIdentifierStart(next)) {
        var end = start + 2;
        while (end < source.len and isIdentifierContinue(source[end])) end += 1;
        return end;
    }
    if (std.ascii.isDigit(next) or std.mem.indexOfScalar(u8, "?*$#@!-_", next) != null) {
        return start + 2;
    }
    return start + 1;
}

pub const AssignmentParts = struct {
    name_end: usize,
    operator_end: usize,
};

fn assignmentOperator(word: []const u8) ?AssignmentParts {
    if (word.len == 0 or !isIdentifierStart(word[0])) return null;
    var name_end: usize = 1;
    while (name_end < word.len and isIdentifierContinue(word[name_end])) name_end += 1;
    var operator_end = name_end;
    if (operator_end < word.len and word[operator_end] == '+') operator_end += 1;
    if (operator_end >= word.len or word[operator_end] != '=') return null;
    return .{ .name_end = name_end, .operator_end = operator_end + 1 };
}

pub fn assignmentParts(word: []const u8) ?AssignmentParts {
    return assignmentOperator(word);
}

fn operatorLength(source: []const u8) usize {
    const operators = [_][]const u8{
        ";;&", "&>>", "&&", "||", "|&", ";;", ";&", ">>", "&>", "<&", ">&", "<>", ">|", "((", "))",
    };
    for (operators) |operator| {
        if (std.mem.startsWith(u8, source, operator)) return operator.len;
    }
    return 1;
}

fn isControlOperator(operator: []const u8) bool {
    const operators = [_][]const u8{ "\n", "|", "||", "|&", ";", ";;", ";&", ";;&", "&", "&&", "(" };
    for (operators) |candidate| {
        if (std.mem.eql(u8, operator, candidate)) return true;
    }
    return false;
}

fn isRedirectionOperator(operator: []const u8) bool {
    const operators = [_][]const u8{ "<", ">", ">>", "<<", "<<-", "<<<", "<&", ">&", "<>", ">|", "&>", "&>>" };
    for (operators) |candidate| {
        if (std.mem.eql(u8, operator, candidate)) return true;
    }
    return false;
}

fn isWordComponent(tag: TokenTag) bool {
    return switch (tag) {
        .word,
        .number,
        .string,
        .expandable_string,
        .variable,
        .command_substitution,
        .arithmetic_substitution,
        .escape,
        => true,
        else => false,
    };
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isWordBoundary(byte: u8) bool {
    return std.ascii.isWhitespace(byte) or
        std.mem.indexOfScalar(u8, "'\"`$\\|&;()<>[]{}", byte) != null;
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "!", "if", "then", "else", "elif", "fi", "for", "while", "until", "do", "done", "case", "esac", "in", "function", "select", "time", "coproc",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) return true;
    }
    return false;
}

fn commandFollowsKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{
        "!", "if", "then", "else", "elif", "while", "until", "do", "time", "coproc",
    };
    for (keywords) |keyword| {
        if (std.mem.eql(u8, word, keyword)) return true;
    }
    return false;
}

pub fn isBuiltin(word: []const u8) bool {
    const builtins = [_][]const u8{
        ".",         ":",        "[",        "alias",   "bg",      "bind",
        "break",     "builtin",  "caller",   "cd",      "command", "compgen",
        "complete",  "compopt",  "continue", "declare", "dirs",    "disown",
        "echo",      "enable",   "eval",     "exec",    "exit",    "export",
        "false",     "fc",       "fg",       "getopts", "hash",    "help",
        "history",   "jobs",     "kill",     "let",     "local",   "logout",
        "mapfile",   "popd",     "printf",   "pushd",   "pwd",     "read",
        "readarray", "readonly", "return",   "set",     "shift",   "shopt",
        "source",    "suspend",  "test",     "times",   "trap",    "true",
        "type",      "typeset",  "ulimit",   "umask",   "unalias", "unset",
        "wait",
    };
    for (builtins) |builtin| {
        if (std.mem.eql(u8, word, builtin)) return true;
    }
    return false;
}

test "Bash parser records assignments commands options and redirections" {
    const source = "OUTPUT=dist zine --output=dist >output.log\n";
    var tree = try parse(std.testing.allocator, source);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .assignment, "OUTPUT=dist");
    try expectNodeMain(&tree, .command_name, "zine");
    try expectNodeMain(&tree, .option, "--output=dist");
    try expectNodeMain(&tree, .redirection_target, "output.log");
    try expectNodeSpan(&tree, .simple_command, "OUTPUT=dist zine --output=dist >output.log");
    try std.testing.expectEqual(@as(usize, 0), tree.diagnostics.len);
    try tree.validate();
}

test "Bash tokenizer keeps digit-leading shell words intact" {
    const source = "zine --host 127.0.0.1 --port 8080\n";
    var tree = try parse(std.testing.allocator, source);
    defer tree.deinit(std.testing.allocator);

    try expectToken(&tree, .word, "127.0.0.1");
    try expectToken(&tree, .number, "8080");
    try expectNodeMain(&tree, .argument, "127.0.0.1");
    try tree.validate();
}

test "Bash parser records function definitions loop variables and body commands" {
    const source =
        \\function render { printf '%s' "$value"; }
        \\publish() { diff -ru old new; }
        \\for item in 1 2; do echo "$item"; done
    ;
    var tree = try parse(std.testing.allocator, source);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .function_name, "render");
    try expectNodeMain(&tree, .function_name, "publish");
    try expectNodeMain(&tree, .loop_variable, "item");
    try expectNodeMain(&tree, .command_name, "printf");
    try expectNodeMain(&tree, .command_name, "diff");
    try expectNodeMain(&tree, .command_name, "echo");
    try std.testing.expectEqual(@as(usize, 0), tree.diagnostics.len);
    try tree.validate();
}

test "Bash parser preserves partial syntax and diagnoses incomplete constructs" {
    const source = "cat <<EOF\nbody\n";
    var tree = try parse(std.testing.allocator, source);
    defer tree.deinit(std.testing.allocator);

    try expectNodeMain(&tree, .command_name, "cat");
    try expectNodeMain(&tree, .redirection_target, "EOF");
    try std.testing.expect(tree.diagnostics.len > 0);
    try tree.validate();
}

test "Bash parser diagnoses unterminated quotes and substitutions" {
    const cases = [_]struct {
        source: []const u8,
        diagnostic: DiagnosticTag,
    }{
        .{ .source = "echo \"$HOME", .diagnostic = .unterminated_string },
        .{ .source = "echo $(date", .diagnostic = .unterminated_command_substitution },
        .{ .source = "echo $((1 + 2)", .diagnostic = .unterminated_arithmetic_substitution },
    };

    for (cases) |case| {
        var tree = try parse(std.testing.allocator, case.source);
        defer tree.deinit(std.testing.allocator);
        try expectDiagnostic(&tree, case.diagnostic);
        try expectNodeMain(&tree, .command_name, "echo");
        try tree.validate();
    }
}

test "Bash parser output is deterministic" {
    const source = "cat <<EOF\nbody\necho \"$HOME";
    var first = try parse(std.testing.allocator, source);
    defer first.deinit(std.testing.allocator);
    var second = try parse(std.testing.allocator, source);
    defer second.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(Syntax.Token, first.tokens, second.tokens);
    try std.testing.expectEqualSlices(Syntax.Node, first.nodes, second.nodes);
    try std.testing.expectEqualSlices(Syntax.Diagnostic, first.diagnostics, second.diagnostics);
}

fn expectNodeMain(tree: *const Tree, tag: NodeTag, expected: []const u8) !void {
    for (tree.nodes) |node| {
        if (node.tag == tag and std.mem.eql(u8, tree.tokenSlice(node.main_token), expected)) return;
    }
    return error.TestExpectedEqual;
}

fn expectToken(tree: *const Tree, tag: TokenTag, expected: []const u8) !void {
    for (tree.tokens) |token| {
        if (token.tag == tag and std.mem.eql(u8, token.slice(tree.source), expected)) return;
    }
    return error.TestExpectedEqual;
}

fn expectNodeSpan(tree: *const Tree, tag: NodeTag, expected: []const u8) !void {
    for (tree.nodes) |node| {
        if (node.tag != tag or node.last_token == node.first_token) continue;
        const start = tree.tokens[node.first_token].start;
        const end = tree.tokens[node.last_token - 1].end;
        if (std.mem.eql(u8, tree.source[start..end], expected)) return;
    }
    return error.TestExpectedEqual;
}

fn expectDiagnostic(tree: *const Tree, expected: DiagnosticTag) !void {
    for (tree.diagnostics) |diagnostic| {
        if (diagnostic.tag == expected) return;
    }
    return error.TestExpectedEqual;
}
