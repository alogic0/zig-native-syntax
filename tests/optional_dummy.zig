const std = @import("std");
const syntax = @import("native_syntax");
const dummy = @import("native_syntax_dummy");

test "enabled optional backend imports and uses its lazy dependency" {
    const source = "dummy value";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();

    try dummy.backend.highlight(source, &sink);
    try std.testing.expectEqualStrings("dummy", dummy.backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, dummy.backend.info.kind);
    try std.testing.expectEqual(@as(usize, 1), sink.captures().len);
    try std.testing.expectEqualStrings(
        "dummy",
        try sink.captures()[0].span.slice(source),
    );
    try std.testing.expectEqual(syntax.Scope.keyword, sink.captures()[0].scope);
}
