const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");
const html_recovery = @import("support/html_recovery.zig");

const iterations_per_backend = 8;
var active_case: ?FuzzCase = null;

const FuzzCase = struct {
    backend_name: []const u8,
    seed: u64,
    iteration: usize,
    source: []const u8,
};

pub const panic = std.debug.FullPanic(fuzzPanic);

fn fuzzPanic(message: []const u8, first_trace_addr: ?usize) noreturn {
    if (active_case) |case| {
        std.debug.print(
            "registry fuzz panic: backend={s} seed=0x{x} iteration={d} source={f}\n",
            .{ case.backend_name, case.seed, case.iteration, std.zig.fmtString(case.source) },
        );
    }
    std.debug.defaultPanic(message, first_trace_addr);
}

test "seeded fuzz exercises every configured backend" {
    const syntax_bytes =
        " \t\r\n\\\"'`/*#$@&|!?+-=<>.,:;()[]{}abcdefghijklmnopqrstuvwxyz0123456789";
    var source_buffer: [512]u8 = undefined;

    for (registry.backends) |backend| {
        const seed = backendSeed(backend.info.canonical_name);
        var prng = std.Random.DefaultPrng.init(seed);
        const random = prng.random();

        for (0..iterations_per_backend) |iteration| {
            const source_len = random.uintLessThan(usize, source_buffer.len + 1);
            for (source_buffer[0..source_len], 0..) |*byte, index| {
                byte.* = if ((iteration + index) % 7 == 0)
                    random.int(u8)
                else
                    syntax_bytes[random.uintLessThan(usize, syntax_bytes.len)];
            }
            active_case = .{
                .backend_name = backend.info.canonical_name,
                .seed = seed,
                .iteration = iteration,
                .source = source_buffer[0..source_len],
            };
            expectSafe(backend, source_buffer[0..source_len]) catch |err| {
                std.log.err(
                    "registry fuzz failure: backend={s} seed=0x{x} iteration={d} source={f}",
                    .{ backend.info.canonical_name, seed, iteration, std.zig.fmtString(source_buffer[0..source_len]) },
                );
                return err;
            };
            active_case = null;
        }
    }
}

fn backendSeed(canonical_name: []const u8) u64 {
    var hash: u64 = 0xcbf2_9ce4_8422_2325;
    for (canonical_name) |byte| {
        hash ^= byte;
        hash *%= 0x0000_0100_0000_01b3;
    }
    return hash ^ 0x4e41_5449_5645_5359;
}

test "backend fuzz seeds are stable and name-specific" {
    try std.testing.expectEqual(@as(u64, 0xd43d_8ad2_fc11_ee06), backendSeed("bash"));
    try std.testing.expect(backendSeed("bash") != backendSeed("rpmbash"));
}

fn expectSafe(backend: syntax.Backend, source: []const u8) !void {
    var first: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer first.deinit();
    try backend.highlight(source, &first);

    var second: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer second.deinit();
    try backend.highlight(source, &second);

    try expectEqualCaptures(first.captures(), second.captures());

    for (first.captures()) |capture| try capture.validate(source.len);

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(
        source,
        first.captures(),
        std.testing.allocator,
        &output.writer,
    );
    if (std.unicode.utf8ValidateSlice(source)) {
        try std.testing.expect(std.unicode.utf8ValidateSlice(output.written()));
    }

    const recovered = try html_recovery.recoverSource(std.testing.allocator, output.written());
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualSlices(u8, source, recovered);
}

fn expectEqualCaptures(expected: []const syntax.Capture, actual: []const syntax.Capture) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_capture, actual_capture| {
        try std.testing.expectEqual(expected_capture.span.start, actual_capture.span.start);
        try std.testing.expectEqual(expected_capture.span.end, actual_capture.span.end);
        try std.testing.expectEqual(expected_capture.scope, actual_capture.scope);
    }
}

fn allocationCase(allocator: std.mem.Allocator, backend: syntax.Backend) !void {
    const source = "const value = \"<&>\";\n";
    var sink: syntax.CaptureSink = .init(allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
}

test "every configured backend handles every allocation failure" {
    for (registry.backends) |backend| {
        active_case = .{
            .backend_name = backend.info.canonical_name,
            .seed = 0,
            .iteration = 0,
            .source = "const value = \"<&>\";\n",
        };
        std.testing.checkAllAllocationFailures(
            std.testing.allocator,
            allocationCase,
            .{backend},
        ) catch |err| {
            std.log.err(
                "allocation failure contract failed: backend={s} error={s}",
                .{ backend.info.canonical_name, @errorName(err) },
            );
            return err;
        };
        active_case = null;
    }
}
