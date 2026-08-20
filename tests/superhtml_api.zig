const std = @import("std");
const superhtml = @import("superhtml");

test "SuperHTML exposes independently consumable HTML and CSS tokenizers" {
    var html_tokenizer: superhtml.html.Tokenizer = .{
        .language = .html,
        .return_attrs = true,
    };
    try std.testing.expect(html_tokenizer.next("<p class='lead'>text</p>") != null);

    var xml_tokenizer: superhtml.html.Tokenizer = .{
        .language = .xml,
        .return_attrs = true,
    };
    try std.testing.expect(xml_tokenizer.next("<item key=\"value\" />") != null);

    var css_tokenizer: superhtml.css.Tokenizer = .{};
    try std.testing.expect(css_tokenizer.next(".lead { color: red; }") != null);
}
