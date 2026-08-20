//! Source-preserving primitives for native syntax highlighting.

const std = @import("std");

pub const Scope = enum {
    keyword,
    type,
    builtin,
    function,
    variable,
    property,
    string,
    number,
    comment,
    tag,
    attribute,
    punctuation,
};

pub const Span = struct {
    start: usize,
    end: usize,
    scope: Scope,

    pub fn init(start: usize, end: usize, scope: Scope) Span {
        std.debug.assert(start <= end);
        return .{
            .start = start,
            .end = end,
            .scope = scope,
        };
    }

    pub fn slice(span: Span, source: []const u8) []const u8 {
        return source[span.start..span.end];
    }
};

test "span preserves source offsets" {
    const source = "const answer = 42;";
    const span: Span = .init(0, 5, .keyword);

    try std.testing.expectEqualStrings("const", span.slice(source));
}
