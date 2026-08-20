const std = @import("std");
const syntax = @import("native_syntax");

fn classifyExample(
    source: []const u8,
    sink: *syntax.CaptureSink,
) syntax.HighlightError!void {
    if (std.mem.startsWith(u8, source, "const")) {
        try sink.add(0, 5, .keyword);
    }
}

const example_backend: syntax.Backend = .init(.{
    .canonical_name = "example",
    .display_name = "Example",
    .kind = .lexical,
}, classifyExample);

test "public API classifies borrowed source into caller-owned captures" {
    const source = "const answer = 42;";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try example_backend.highlight(source, &sink);

    const captures = sink.captures();
    try std.testing.expectEqual(@as(usize, 1), captures.len);
    try std.testing.expectEqual(syntax.Scope.keyword, captures[0].scope);
    try std.testing.expectEqualStrings(
        "const",
        try captures[0].span.slice(source),
    );
    try std.testing.expectEqualStrings(
        "syntax-keyword",
        captures[0].scope.cssClass(),
    );
}

test "public API transfers capture allocation explicitly" {
    const source = "const";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try example_backend.highlight(source, &sink);
    const owned = try sink.toOwnedSlice();
    defer std.testing.allocator.free(owned);

    try std.testing.expectEqual(@as(usize, 1), owned.len);
    try std.testing.expectEqual(@as(usize, 0), sink.captures().len);
}

test "public API renders escaped plain text" {
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try syntax.html.renderPlain("<unsafe>&", &output.writer);
    try std.testing.expectEqualStrings(
        "&lt;unsafe&gt;&amp;",
        output.written(),
    );
}

test "all public declarations are referenced" {
    std.testing.refAllDecls(syntax);
}
