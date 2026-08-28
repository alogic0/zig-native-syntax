const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");

test "seeded fuzz exercises every configured backend" {
    var prng = std.Random.DefaultPrng.init(0x4e41_5449_5645_5359);
    const random = prng.random();
    const syntax_bytes =
        " \t\r\n\\\"'`/*#$@&|!?+-=<>.,:;()[]{}abcdefghijklmnopqrstuvwxyz0123456789";
    var source_buffer: [512]u8 = undefined;

    for (0..512) |iteration| {
        const backend_index = if (iteration < registry.backends.len)
            iteration
        else
            random.uintLessThan(usize, registry.backends.len);
        const source_len = random.uintLessThan(usize, source_buffer.len + 1);
        for (source_buffer[0..source_len], 0..) |*byte, index| {
            byte.* = if ((iteration + index) % 7 == 0)
                random.int(u8)
            else
                syntax_bytes[random.uintLessThan(usize, syntax_bytes.len)];
        }
        try expectSafe(
            registry.backends[backend_index],
            source_buffer[0..source_len],
        );
    }
}

fn expectSafe(backend: syntax.Backend, source: []const u8) !void {
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    for (sink.captures()) |capture| try capture.validate(source.len);

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(
        source,
        sink.captures(),
        std.testing.allocator,
        &output.writer,
    );
    if (std.unicode.utf8ValidateSlice(source)) {
        try std.testing.expect(std.unicode.utf8ValidateSlice(output.written()));
    }
}
