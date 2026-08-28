const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;

pub const TokenKind = enum { word, l_paren, r_paren, comma, colon, percent, arrow, equal };

pub const Token = struct {
    start: usize,
    end: usize,
    kind: TokenKind,
    lexical_scope: ?Scope = null,
    role: ?Scope = null,
};

pub const State = struct {
    in_derived_type: bool = false,
};

pub fn classifyLine(source: []const u8, sink: *api.CaptureSink, tokens: []Token, state: *State) api.HighlightError!void {
    if (tokens.len == 0) return;
    const first = nextWord(tokens, 0) orelse return;
    const second = nextWord(tokens, first + 1);
    const is_end_type = wordEq(source, tokens[first], "endtype") or
        (wordEq(source, tokens[first], "end") and second != null and wordEq(source, tokens[second.?], "type"));

    markComponents(tokens);
    markNamedStatement(source, tokens);
    markDeclarations(source, tokens, first, state);
    markCalls(tokens);

    for (tokens) |token| {
        if (token.kind != .word) continue;
        if (token.role) |role| {
            try sink.add(token.start, token.end, role);
        } else if (token.lexical_scope == null) {
            try sink.add(token.start, token.end, .variable);
        }
    }
    if (is_end_type) state.in_derived_type = false;
}

fn markComponents(tokens: []Token) void {
    for (tokens, 0..) |token, index| {
        if (token.kind == .percent) {
            if (nextWord(tokens, index + 1)) |member| tokens[member].role = .property;
        }
    }
}

fn markNamedStatement(source: []const u8, tokens: []Token) void {
    if (tokens.len > 1 and tokens[0].kind == .word and tokens[1].kind == .colon and tokens[1].end - tokens[1].start == 1) tokens[0].role = .label;
    for (tokens, 0..) |token, index| {
        if (token.kind != .word) continue;
        if (wordEq(source, token, "call")) {
            if (nextWord(tokens, index + 1)) |name| tokens[name].role = .function;
        } else if (wordEq(source, token, "result")) {
            if (wordInsideFollowingParens(tokens, index)) |name| tokens[name].role = .variable;
        }
    }
}

fn markCalls(tokens: []Token) void {
    for (tokens, 0..) |token, index| {
        if (token.kind != .word or token.lexical_scope != null) continue;
        if (nextToken(tokens, index + 1)) |next| {
            if (tokens[next].kind == .l_paren and token.role == null) tokens[index].role = .function;
        }
    }
}

fn markDeclarations(source: []const u8, tokens: []Token, first: usize, state: *State) void {
    if (isEndStatement(source, tokens[first])) {
        markEndName(source, tokens, first);
        return;
    }
    if (wordEq(source, tokens[first], "program")) {
        markNext(tokens, first + 1, .namespace);
        return;
    }
    if (wordEq(source, tokens[first], "module")) {
        const name = nextWord(tokens, first + 1) orelse return;
        if (wordEq(source, tokens[name], "procedure")) {
            markWordsAfter(tokens, name + 1, .function);
        } else {
            tokens[name].role = .namespace;
        }
        return;
    }
    if (wordEq(source, tokens[first], "submodule")) {
        markWordsAfter(tokens, first + 1, .namespace);
        return;
    }
    if (wordEq(source, tokens[first], "use")) {
        const separator = findKind(tokens, first + 1, .colon);
        markNext(tokens, if (separator) |index| index + 1 else first + 1, .namespace);
        return;
    }
    if (wordEq(source, tokens[first], "interface")) {
        markNext(tokens, first + 1, .type);
        return;
    }
    if (findWord(source, tokens, "subroutine")) |keyword| {
        markProcedureDeclaration(tokens, keyword);
        return;
    }
    if (findWord(source, tokens, "function")) |keyword| {
        markProcedureDeclaration(tokens, keyword);
        return;
    }
    if (wordEq(source, tokens[first], "type")) {
        if (wordInsideFollowingParens(tokens, first)) |name| {
            tokens[name].role = .type;
            markVariableDeclaration(tokens, first, state.in_derived_type);
        } else if (findKind(tokens, first + 1, .colon)) |separator| {
            if (nextWord(tokens, separator + 1)) |name| {
                tokens[name].role = .type;
                state.in_derived_type = true;
            }
            if (findWord(source, tokens, "extends")) |extends| {
                if (wordInsideFollowingParens(tokens, extends)) |parent| tokens[parent].role = .type;
            }
        }
        return;
    }
    if (wordEq(source, tokens[first], "class")) {
        if (wordInsideFollowingParens(tokens, first)) |name| tokens[name].role = .type;
        markVariableDeclaration(tokens, first, state.in_derived_type);
        return;
    }
    if (wordEq(source, tokens[first], "procedure")) {
        if (wordInsideFollowingParens(tokens, first)) |interface_name| tokens[interface_name].role = .type;
        const separator = findKind(tokens, first + 1, .colon);
        markWordsAfter(tokens, if (separator) |index| index + 1 else first + 1, if (state.in_derived_type) .property else .function);
        if (findKind(tokens, first + 1, .arrow)) |arrow| markWordsAfter(tokens, arrow + 1, .function);
        return;
    }
    if (tokens[first].lexical_scope == .type) markVariableDeclaration(tokens, first, state.in_derived_type);
}

fn markProcedureDeclaration(tokens: []Token, keyword: usize) void {
    if (nextWord(tokens, keyword + 1)) |name| {
        tokens[name].role = .function;
        markParameters(tokens, name);
    }
}

fn markVariableDeclaration(tokens: []Token, first: usize, in_derived_type: bool) void {
    const separator = findKind(tokens, first + 1, .colon);
    var start = if (separator) |index| index + 1 else first + 1;
    if (separator == null and tokens[first].lexical_scope == .type) {
        if (nextWord(tokens, start)) |maybe_second_type| {
            if (tokens[maybe_second_type].lexical_scope == .type) start = maybe_second_type + 1;
        }
    }
    var in_initializer = false;
    for (tokens[start..]) |*token| {
        switch (token.kind) {
            .comma => in_initializer = false,
            .equal, .arrow => in_initializer = true,
            .word => if (!in_initializer and token.role == null) {
                token.role = if (in_derived_type) .property else .variable;
            },
            else => {},
        }
    }
}

fn markEndName(source: []const u8, tokens: []Token, first: usize) void {
    var cursor = first + 1;
    if (wordEq(source, tokens[first], "end")) {
        const kind = nextWord(tokens, cursor) orelse return;
        cursor = kind + 1;
        const role = endRole(source, tokens[kind]) orelse return;
        markNext(tokens, cursor, role);
        return;
    }
    const role = endRole(source, tokens[first]) orelse return;
    markNext(tokens, cursor, role);
}

fn isEndStatement(source: []const u8, token: Token) bool {
    return wordEq(source, token, "end") or wordEq(source, token, "endprogram") or wordEq(source, token, "endmodule") or
        wordEq(source, token, "endsubmodule") or wordEq(source, token, "endsubroutine") or wordEq(source, token, "endfunction") or
        wordEq(source, token, "endinterface") or wordEq(source, token, "endtype");
}

fn endRole(source: []const u8, token: Token) ?Scope {
    if (wordEq(source, token, "program") or wordEq(source, token, "module") or wordEq(source, token, "submodule") or
        wordEq(source, token, "endprogram") or wordEq(source, token, "endmodule") or wordEq(source, token, "endsubmodule")) return .namespace;
    if (wordEq(source, token, "function") or wordEq(source, token, "subroutine") or
        wordEq(source, token, "endfunction") or wordEq(source, token, "endsubroutine")) return .function;
    if (wordEq(source, token, "type") or wordEq(source, token, "interface") or
        wordEq(source, token, "endtype") or wordEq(source, token, "endinterface")) return .type;
    return null;
}

fn wordEq(source: []const u8, token: Token, expected: []const u8) bool {
    return token.kind == .word and std.ascii.eqlIgnoreCase(source[token.start..token.end], expected);
}

fn nextWord(tokens: []const Token, start: usize) ?usize {
    for (tokens[start..], start..) |token, index| if (token.kind == .word) return index;
    return null;
}

fn nextToken(tokens: []const Token, start: usize) ?usize {
    return if (start < tokens.len) start else null;
}

fn findWord(source: []const u8, tokens: []const Token, expected: []const u8) ?usize {
    for (tokens, 0..) |token, index| if (wordEq(source, token, expected)) return index;
    return null;
}

fn findKind(tokens: []const Token, start: usize, kind: TokenKind) ?usize {
    for (tokens[start..], start..) |token, index| if (token.kind == kind) return index;
    return null;
}

fn markNext(tokens: []Token, start: usize, role: Scope) void {
    if (nextWord(tokens, start)) |index| tokens[index].role = role;
}

fn markWordsAfter(tokens: []Token, start: usize, role: Scope) void {
    for (tokens[start..]) |*token| {
        if (token.kind == .word and token.role == null) token.role = role;
    }
}

fn wordInsideFollowingParens(tokens: []const Token, word: usize) ?usize {
    const open = nextToken(tokens, word + 1) orelse return null;
    if (tokens[open].kind != .l_paren) return null;
    return nextWord(tokens, open + 1);
}

fn markParameters(tokens: []Token, name: usize) void {
    const open = nextToken(tokens, name + 1) orelse return;
    if (tokens[open].kind != .l_paren) return;
    var depth: usize = 1;
    for (tokens[open + 1 ..]) |*token| {
        switch (token.kind) {
            .l_paren => depth += 1,
            .r_paren => {
                depth -= 1;
                if (depth == 0) return;
            },
            .word => if (depth == 1 and token.role == null) {
                token.role = .parameter;
            },
            else => {},
        }
    }
}
