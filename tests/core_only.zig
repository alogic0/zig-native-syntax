const std = @import("std");
const syntax = @import("native_syntax");

test "core-only module exposes standard-library backends without optional modules" {
    try std.testing.expectEqualStrings("zig", syntax.languages.zig.backend.info.canonical_name);
    try std.testing.expect(!@hasDecl(syntax.languages, "dummy"));

    var sink: syntax.CaptureSink = .init(std.testing.allocator, 5);
    defer sink.deinit();
    try syntax.languages.zig.backend.highlight("const", &sink);
    try std.testing.expect(sink.captures().len != 0);
}
