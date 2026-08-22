const std = @import("std");
const syntax = @import("native_syntax");
const bash_lexical = @import("bash_lexical");
const javascript_lexical = @import("javascript_lexical");

const default_iterations: usize = 1_000;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const iterations = if (args.len > 1)
        try std.fmt.parseInt(usize, args[1], 10)
    else
        default_iterations;
    if (iterations == 0) return error.InvalidIterations;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try benchmarkCase(init, stdout, .{
        .name = "Bash",
        .path = "tests/corpus/bash/complete.sh",
        .lexical = bash_lexical.backend,
        .structural = syntax.languages.bash.backend,
    }, iterations);
    try benchmarkCase(init, stdout, .{
        .name = "JavaScript",
        .path = "tests/corpus/javascript/complete.js",
        .lexical = javascript_lexical.backend,
        .structural = syntax.languages.javascript.backend,
    }, iterations);
    try stdout.flush();
}

const Case = struct {
    name: []const u8,
    path: []const u8,
    lexical: syntax.Backend,
    structural: syntax.Backend,
};

fn benchmarkCase(
    init: std.process.Init,
    writer: *std.Io.Writer,
    case: Case,
    iterations: usize,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        case.path,
        init.gpa,
        .limited(std.math.maxInt(u32)),
    );
    defer init.gpa.free(source);

    const lexical_allocations = try measureAllocations(init.gpa, case.lexical, source);
    const structural_allocations = try measureAllocations(init.gpa, case.structural, source);
    const lexical = try measureTime(init, case.lexical, source, iterations);
    const structural = try measureTime(init, case.structural, source, iterations);

    try writer.print(
        \\{s} syntax-core benchmark
        \\  source: {s} ({d} bytes, {d} iterations)
        \\  lexical:    {d:.2} MiB/s, {d} captures, {d} allocations, {d} requested bytes, {d} peak bytes
        \\  structural: {d:.2} MiB/s, {d} captures, {d} allocations, {d} requested bytes, {d} peak bytes
        \\  throughput ratio: {d:.3}x
        \\  checksum: {d}
        \\
    , .{
        case.name,
        case.path,
        source.len,
        iterations,
        throughput(source.len * iterations, lexical.elapsed_ns),
        lexical.capture_count,
        lexical_allocations.calls,
        lexical_allocations.requested_bytes,
        lexical_allocations.peak_bytes,
        throughput(source.len * iterations, structural.elapsed_ns),
        structural.capture_count,
        structural_allocations.calls,
        structural_allocations.requested_bytes,
        structural_allocations.peak_bytes,
        ratio(lexical.elapsed_ns, structural.elapsed_ns),
        lexical.checksum +% structural.checksum,
    });
}

const Timing = struct {
    elapsed_ns: i96,
    capture_count: usize,
    checksum: usize,
};

fn measureTime(
    init: std.process.Init,
    backend: syntax.Backend,
    source: []const u8,
    iterations: usize,
) !Timing {
    var warm_sink: syntax.CaptureSink = .init(init.gpa, source.len);
    defer warm_sink.deinit();
    try backend.highlight(source, &warm_sink);
    const capture_count = warm_sink.captures().len;

    var checksum: usize = 0;
    const start = std.Io.Clock.awake.now(init.io).nanoseconds;
    for (0..iterations) |_| {
        var sink: syntax.CaptureSink = .init(init.gpa, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);
        checksum +%= sink.captures().len;
    }
    const end = std.Io.Clock.awake.now(init.io).nanoseconds;
    return .{
        .elapsed_ns = end - start,
        .capture_count = capture_count,
        .checksum = checksum,
    };
}

const AllocationMeasurement = struct {
    calls: usize,
    requested_bytes: usize,
    peak_bytes: usize,
};

fn measureAllocations(
    backing_allocator: std.mem.Allocator,
    backend: syntax.Backend,
    source: []const u8,
) !AllocationMeasurement {
    var counter: CountingAllocator = .{ .backing = backing_allocator };
    {
        var sink: syntax.CaptureSink = .init(counter.allocator(), source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);
    }
    std.debug.assert(counter.current_bytes == 0);
    return .{
        .calls = counter.calls,
        .requested_bytes = counter.requested_bytes,
        .peak_bytes = counter.peak_bytes,
    };
}

fn throughput(byte_count: usize, elapsed_ns: i96) f64 {
    const bytes: f64 = @floatFromInt(byte_count);
    const nanoseconds: f64 = @floatFromInt(elapsed_ns);
    return bytes * @as(f64, std.time.ns_per_s) / nanoseconds / (1024.0 * 1024.0);
}

fn ratio(lexical_ns: i96, structural_ns: i96) f64 {
    const lexical: f64 = @floatFromInt(lexical_ns);
    const structural: f64 = @floatFromInt(structural_ns);
    return lexical / structural;
}

const CountingAllocator = struct {
    backing: std.mem.Allocator,
    calls: usize = 0,
    requested_bytes: usize = 0,
    current_bytes: usize = 0,
    peak_bytes: usize = 0,

    fn allocator(counter: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = counter, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn alloc(
        context: *anyopaque,
        len: usize,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) ?[*]u8 {
        const counter: *CountingAllocator = @ptrCast(@alignCast(context));
        const result = counter.backing.rawAlloc(len, alignment, return_address);
        if (result != null) {
            counter.calls += 1;
            counter.requested_bytes += len;
            counter.current_bytes += len;
            counter.peak_bytes = @max(counter.peak_bytes, counter.current_bytes);
        }
        return result;
    }

    fn resize(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) bool {
        const counter: *CountingAllocator = @ptrCast(@alignCast(context));
        if (!counter.backing.rawResize(memory, alignment, new_len, return_address)) return false;
        counter.recordResize(memory.len, new_len);
        return true;
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_len: usize,
        return_address: usize,
    ) ?[*]u8 {
        const counter: *CountingAllocator = @ptrCast(@alignCast(context));
        const result = counter.backing.rawRemap(memory, alignment, new_len, return_address);
        if (result != null) counter.recordResize(memory.len, new_len);
        return result;
    }

    fn free(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        return_address: usize,
    ) void {
        const counter: *CountingAllocator = @ptrCast(@alignCast(context));
        counter.current_bytes -= memory.len;
        counter.backing.rawFree(memory, alignment, return_address);
    }

    fn recordResize(counter: *CountingAllocator, old_len: usize, new_len: usize) void {
        if (new_len > old_len) {
            const increase = new_len - old_len;
            counter.requested_bytes += increase;
            counter.current_bytes += increase;
            counter.peak_bytes = @max(counter.peak_bytes, counter.current_bytes);
        } else {
            counter.current_bytes -= old_len - new_len;
        }
    }
};
