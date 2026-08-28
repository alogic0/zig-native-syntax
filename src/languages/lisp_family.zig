const std = @import("std");
const api = @import("../backend.zig");
const Scope = @import("../scope.zig").Scope;
const scanner = @import("scanner_support.zig");

pub const Dialect = enum { common_lisp, scheme };

pub fn highlight(source: []const u8, sink: *api.CaptureSink, dialect: Dialect) api.HighlightError!void {
    var parser: Parser = .{ .source = source, .sink = sink, .dialect = dialect };
    try parser.run();
}

const Kind = enum {
    normal,
    quoted,
    define_function,
    define_macro,
    define_type,
    define_namespace,
    define_variable,
    define_constant,
    scheme_define,
    lambda,
    let,
    parameters,
    scheme_signature,
    bindings,
    binding,
    slots,
    slot,
    namespace_parts,
};

const Frame = struct {
    kind: Kind = .normal,
    words: usize = 0,
    children: usize = 0,
};

const Parser = struct {
    source: []const u8,
    sink: *api.CaptureSink,
    dialect: Dialect,
    index: usize = 0,
    frames: [64]Frame = @splat(.{}),
    depth: usize = 0,
    quoted_next: bool = false,

    fn run(parser: *Parser) api.HighlightError!void {
        while (parser.index < parser.source.len) {
            if (parser.startsWith("#|")) {
                parser.skipBlockComment();
                continue;
            }
            switch (parser.source[parser.index]) {
                ' ', '\t', '\r', '\n' => parser.index += 1,
                ';' => parser.index = scanner.lineEnd(parser.source, parser.index, parser.source.len),
                '"' => parser.index = scanner.quotedEnd(parser.source, parser.index, '"', true),
                '\'', '`' => {
                    parser.quoted_next = true;
                    parser.index += 1;
                },
                ',' => parser.index += if (parser.index + 1 < parser.source.len and parser.source[parser.index + 1] == '@') 2 else 1,
                '(', '[' => parser.pushFrame(),
                ')', ']' => parser.popFrame(),
                else => {
                    if (isSymbolByte(parser.source[parser.index])) try parser.scanSymbol() else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
                },
            }
        }
    }

    fn pushFrame(parser: *Parser) void {
        const kind: Kind = if (parser.quoted_next)
            .quoted
        else if (parser.depth == 0)
            .normal
        else switch (parser.frames[parser.depth - 1].kind) {
            .quoted => .quoted,
            .define_function, .define_macro, .lambda => if (parser.frames[parser.depth - 1].words >= 2 or parser.frames[parser.depth - 1].kind == .lambda) .parameters else .normal,
            .scheme_define => if (parser.frames[parser.depth - 1].words == 1 and parser.frames[parser.depth - 1].children == 0) .scheme_signature else .normal,
            .let => if (parser.frames[parser.depth - 1].words == 1) .bindings else .normal,
            .bindings => .binding,
            .parameters => .parameters,
            .define_type => if (parser.frames[parser.depth - 1].children >= 1) .slots else .normal,
            .define_namespace => if (parser.frames[parser.depth - 1].words == 1 and parser.frames[parser.depth - 1].children == 0) .namespace_parts else .normal,
            .slots => .slot,
            else => .normal,
        };
        parser.quoted_next = false;
        if (parser.depth < parser.frames.len) {
            if (parser.depth > 0) parser.frames[parser.depth - 1].children += 1;
            parser.frames[parser.depth] = .{ .kind = kind };
            parser.depth += 1;
        }
        parser.index += 1;
    }

    fn popFrame(parser: *Parser) void {
        parser.depth -|= 1;
        parser.quoted_next = false;
        parser.index += 1;
    }

    fn scanSymbol(parser: *Parser) api.HighlightError!void {
        const start = parser.index;
        parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        while (parser.index < parser.source.len and isSymbolByte(parser.source[parser.index])) {
            parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
        const word = parser.source[start..parser.index];
        if (parser.quoted_next) {
            parser.quoted_next = false;
            try parser.sink.add(start, parser.index, .constant);
            return;
        }
        if (parser.depth == 0 or std.ascii.isDigit(word[0])) return;

        var frame = &parser.frames[parser.depth - 1];
        const first = frame.words == 0;
        frame.words += 1;

        if (frame.kind == .quoted) {
            try parser.sink.add(start, parser.index, .constant);
            return;
        }
        if (isBoolean(word, parser.dialect)) {
            try parser.sink.add(start, parser.index, .boolean);
            return;
        }
        if (isConstant(word)) {
            try parser.sink.add(start, parser.index, .constant);
            return;
        }
        switch (frame.kind) {
            .parameters => {
                if (word[0] != '&') try parser.sink.add(start, parser.index, if (std.ascii.isUpper(word[0])) .type else .parameter);
                return;
            },
            .scheme_signature => {
                try parser.sink.add(start, parser.index, if (first) .function else .parameter);
                return;
            },
            .binding => if (first) {
                try parser.sink.add(start, parser.index, .variable);
                return;
            },
            .slot => if (first) {
                try parser.sink.add(start, parser.index, .property);
                return;
            },
            .slots => if (first) {
                try parser.sink.add(start, parser.index, .property);
                return;
            },
            .namespace_parts => {
                try parser.sink.add(start, parser.index, .namespace);
                return;
            },
            else => {},
        }
        if (first) {
            if (parser.formKind(word)) |kind| {
                frame.kind = kind;
            } else {
                try parser.sink.add(start, parser.index, .function);
            }
            return;
        }

        switch (frame.kind) {
            .define_function => if (frame.words == 2) try parser.sink.add(start, parser.index, .function) else try parser.captureValue(start),
            .define_macro => if (frame.words == 2) try parser.sink.add(start, parser.index, .macro) else try parser.captureValue(start),
            .define_type => if (frame.words == 2) try parser.sink.add(start, parser.index, .type) else try parser.sink.add(start, parser.index, .property),
            .define_namespace => if (frame.words == 2) try parser.sink.add(start, parser.index, .namespace) else try parser.captureValue(start),
            .define_variable => if (frame.words == 2) try parser.sink.add(start, parser.index, .variable) else try parser.captureValue(start),
            .define_constant => if (frame.words == 2) try parser.sink.add(start, parser.index, .constant) else try parser.captureValue(start),
            .scheme_define => if (frame.words == 2) try parser.sink.add(start, parser.index, .variable) else try parser.captureValue(start),
            .parameters, .scheme_signature, .binding, .slot, .slots, .namespace_parts => try parser.captureValue(start),
            else => try parser.captureValue(start),
        }
    }

    fn captureValue(parser: *Parser, start: usize) api.HighlightError!void {
        const word = parser.source[start..parser.index];
        if (std.ascii.isUpper(word[0])) {
            try parser.sink.add(start, parser.index, .type);
        } else {
            try parser.sink.add(start, parser.index, .variable);
        }
    }

    fn formKind(parser: Parser, word: []const u8) ?Kind {
        if (wordIs(word, &.{ "defun", "defgeneric", "defmethod" })) return .define_function;
        if (wordIs(word, &.{ "defmacro", "define-syntax" })) return .define_macro;
        if (wordIs(word, &.{ "defclass", "defstruct", "deftype", "define-record-type" })) return .define_type;
        if (wordIs(word, &.{ "defpackage", "define-library", "import", "in-package" })) return .define_namespace;
        if (wordIs(word, &.{ "defvar", "defparameter" })) return .define_variable;
        if (std.mem.eql(u8, word, "defconstant")) return .define_constant;
        if (parser.dialect == .scheme and std.mem.eql(u8, word, "define")) return .scheme_define;
        if (std.mem.eql(u8, word, "lambda")) return .lambda;
        if (wordIs(word, &.{ "let", "let*", "letrec", "letrec*" })) return .let;
        return null;
    }

    fn startsWith(parser: Parser, text: []const u8) bool {
        return std.mem.startsWith(u8, parser.source[parser.index..], text);
    }

    fn skipBlockComment(parser: *Parser) void {
        parser.index += 2;
        var depth: usize = 1;
        while (parser.index < parser.source.len and depth > 0) {
            if (parser.startsWith("#|")) {
                depth += 1;
                parser.index += 2;
            } else if (parser.startsWith("|#")) {
                depth -= 1;
                parser.index += 2;
            } else parser.index += scanner.validUtf8Length(parser.source[parser.index..]);
        }
    }
};

fn isSymbolByte(byte: u8) bool {
    return !std.ascii.isWhitespace(byte) and std.mem.indexOfScalar(u8, "()[]{}\"';`,", byte) == null;
}

fn isBoolean(word: []const u8, dialect: Dialect) bool {
    return if (dialect == .common_lisp)
        wordIs(word, &.{"t"})
    else
        wordIs(word, &.{ "#t", "#f" });
}

fn isConstant(word: []const u8) bool {
    return std.mem.eql(u8, word, "nil") or word[0] == ':' or
        (word.len > 2 and word[0] == '+' and word[word.len - 1] == '+');
}

const wordIs = scanner.wordIs;
