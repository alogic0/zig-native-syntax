const std = @import("std");
const Writer = std.Io.Writer;

/// Writes source as escaped HTML text without adding any markup.
///
/// The function operates on bytes rather than Unicode code points. Invalid
/// UTF-8 is therefore preserved unchanged except for ASCII bytes that require
/// escaping in HTML.
pub fn renderPlain(source: []const u8, writer: *Writer) Writer.Error!void {
    var unescaped_start: usize = 0;

    for (source, 0..) |byte, index| {
        const entity = switch (byte) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            else => continue,
        };

        try writer.writeAll(source[unescaped_start..index]);
        try writer.writeAll(entity);
        unescaped_start = index + 1;
    }

    try writer.writeAll(source[unescaped_start..]);
}

test "plain renderer escapes HTML-sensitive bytes" {
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain("&<>\"'", &output.writer);
    try std.testing.expectEqualStrings(
        "&amp;&lt;&gt;&quot;&#39;",
        output.written(),
    );
}

test "plain renderer preserves whitespace and ordinary source" {
    const source = "const answer = 42;\n\t// unchanged\n";
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain(source, &output.writer);
    try std.testing.expectEqualStrings(source, output.written());
}

test "plain renderer preserves invalid UTF-8 bytes" {
    const source = [_]u8{ 0xff, '<', 0x80 };
    const expected = [_]u8{ 0xff, '&', 'l', 't', ';', 0x80 };
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain(&source, &output.writer);
    try std.testing.expectEqualSlices(u8, &expected, output.written());
}

test "plain renderer accepts empty input" {
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain("", &output.writer);
    try std.testing.expectEqual(@as(usize, 0), output.written().len);
}
