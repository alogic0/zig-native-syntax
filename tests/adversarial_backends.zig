const std = @import("std");
const syntax = @import("native_syntax");

test "Nix interpolation depth is bounded" {
    const depth = 4096;
    const source = try std.testing.allocator.alloc(u8, depth * 3 + "value".len);
    defer std.testing.allocator.free(source);

    for (0..depth) |index| {
        source[index * 2] = '$';
        source[index * 2 + 1] = '{';
    }
    @memcpy(source[depth * 2 ..][0.."value".len], "value");
    @memset(source[depth * 2 + "value".len ..], '}');

    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.nix.backend.highlight(source, &sink);

    // Each permitted interpolation level performs a bounded amount of work
    // per input byte; nesting beyond that limit is retained as embedded text.
    try std.testing.expect(sink.captures().len < source.len * 40);
    for (sink.captures()) |capture| try capture.validate(source.len);
}

test "large malformed inputs remain recoverable" {
    try expectLargeMalformed(syntax.languages.nix.backend, "${");
    try expectLargeMalformed(syntax.languages.php.backend, "<?php \"");
    try expectLargeMalformed(syntax.languages.objc.backend, "\"");
    try expectLargeMalformed(syntax.languages.fish.backend, "\"");
}

fn expectLargeMalformed(backend: syntax.Backend, prefix: []const u8) !void {
    const source_len = 1024 * 1024;
    const source = try std.testing.allocator.alloc(u8, source_len);
    defer std.testing.allocator.free(source);
    @memset(source, 'x');
    @memcpy(source[0..prefix.len], prefix);

    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    // Capture growth must remain proportional to the input rather than the
    // product of input size and malformed nesting depth.
    try std.testing.expect(sink.captures().len <= source.len);
    for (sink.captures()) |capture| try capture.validate(source.len);
}
