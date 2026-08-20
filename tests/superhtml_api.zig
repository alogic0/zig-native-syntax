const std = @import("std");
const html = @import("superhtml_html");
const css = @import("superhtml_css");
const template_syntax = @import("superhtml_template");

test "SuperHTML exposes independently consumable syntax modules" {
    var html_tokenizer: html.Tokenizer = .{
        .language = .html,
        .return_attrs = true,
    };
    try std.testing.expect(html_tokenizer.next("<p class='lead'>text</p>") != null);

    var xml_tokenizer: html.Tokenizer = .{
        .language = .xml,
        .return_attrs = true,
    };
    try std.testing.expect(xml_tokenizer.next("<item key=\"value\" />") != null);

    var css_tokenizer: css.Tokenizer = .{ .return_comments = true };
    switch (css_tokenizer.next("/* lead */").?) {
        .comment => |span| try std.testing.expectEqualStrings("/* lead */", span.slice("/* lead */")),
        else => return error.TestExpectedEqual,
    }

    const source = "<div :if=\"$ready\">";
    var template_tokenizer: html.Tokenizer = .{
        .language = .superhtml,
        .return_attrs = true,
    };
    while (template_tokenizer.next(source)) |token| switch (token) {
        .attr => |attr| {
            const expression = template_syntax.embeddedExpression(attr, source) orelse continue;
            try std.testing.expectEqualStrings("$ready", expression.span.slice(source));
            return;
        },
        else => {},
    };
    return error.TestExpectedEqual;
}
