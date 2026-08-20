const std = @import("std");

/// A language-neutral syntax classification.
///
/// Scopes are composable rather than mutually exclusive. A backend can emit
/// multiple captures over the same source range when a construct has more
/// than one useful role, such as a builtin type or documentation comment.
pub const Scope = enum {
    attribute,
    boolean,
    builtin,
    comment,
    constant,
    constructor,
    documentation,
    embedded,
    escape,
    function,
    invalid,
    keyword,
    label,
    macro,
    namespace,
    number,
    operator,
    parameter,
    property,
    punctuation,
    special,
    string,
    tag,
    type,
    variable,

    markup_code,
    markup_emphasis,
    markup_heading,
    markup_link,
    markup_list,
    markup_quote,
    markup_strikethrough,
    markup_strong,

    /// Returns the stable CSS class emitted for this scope.
    ///
    /// Class names are controlled entirely by the library. Source text and
    /// backend metadata never become part of an emitted class name.
    pub fn cssClass(scope: Scope) []const u8 {
        return switch (scope) {
            .attribute => "syntax-attribute",
            .boolean => "syntax-boolean",
            .builtin => "syntax-builtin",
            .comment => "syntax-comment",
            .constant => "syntax-constant",
            .constructor => "syntax-constructor",
            .documentation => "syntax-documentation",
            .embedded => "syntax-embedded",
            .escape => "syntax-escape",
            .function => "syntax-function",
            .invalid => "syntax-invalid",
            .keyword => "syntax-keyword",
            .label => "syntax-label",
            .macro => "syntax-macro",
            .namespace => "syntax-namespace",
            .number => "syntax-number",
            .operator => "syntax-operator",
            .parameter => "syntax-parameter",
            .property => "syntax-property",
            .punctuation => "syntax-punctuation",
            .special => "syntax-special",
            .string => "syntax-string",
            .tag => "syntax-tag",
            .type => "syntax-type",
            .variable => "syntax-variable",
            .markup_code => "syntax-markup-code",
            .markup_emphasis => "syntax-markup-emphasis",
            .markup_heading => "syntax-markup-heading",
            .markup_link => "syntax-markup-link",
            .markup_list => "syntax-markup-list",
            .markup_quote => "syntax-markup-quote",
            .markup_strikethrough => "syntax-markup-strikethrough",
            .markup_strong => "syntax-markup-strong",
        };
    }
};

test "scope CSS classes are safe and unique" {
    const scopes = std.enums.values(Scope);

    for (scopes, 0..) |scope, index| {
        const class = scope.cssClass();
        try std.testing.expect(std.mem.startsWith(u8, class, "syntax-"));

        for (class) |byte| {
            try std.testing.expect(std.ascii.isLower(byte) or
                std.ascii.isDigit(byte) or byte == '-');
        }

        for (scopes[index + 1 ..]) |other| {
            try std.testing.expect(!std.mem.eql(u8, class, other.cssClass()));
        }
    }
}
