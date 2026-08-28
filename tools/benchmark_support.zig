const std = @import("std");
const syntax = @import("native_syntax");

pub const Timing = struct {
    elapsed_ns: i96,
    capture_count: usize,
    checksum: usize,
};

pub const AllocationMeasurement = struct {
    calls: usize,
    requested_bytes: usize,
    peak_bytes: usize,
};

pub fn measureTime(
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

pub fn measureAllocations(
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

pub fn throughput(byte_count: usize, elapsed_ns: i96) f64 {
    const bytes: f64 = @floatFromInt(byte_count);
    const nanoseconds: f64 = @floatFromInt(elapsed_ns);
    return bytes * @as(f64, std.time.ns_per_s) / nanoseconds / (1024.0 * 1024.0);
}

pub fn latency(elapsed_ns: i96, iterations: usize) f64 {
    const nanoseconds: f64 = @floatFromInt(elapsed_ns);
    return nanoseconds / @as(f64, @floatFromInt(iterations));
}

pub fn ratio(baseline_ns: i96, candidate_ns: i96) f64 {
    const baseline: f64 = @floatFromInt(baseline_ns);
    const candidate: f64 = @floatFromInt(candidate_ns);
    return baseline / candidate;
}

pub fn repeatSource(allocator: std.mem.Allocator, source: []const u8, repetitions: usize) ![]u8 {
    const result = try allocator.alloc(u8, source.len * repetitions);
    for (0..repetitions) |index| {
        @memcpy(result[index * source.len ..][0..source.len], source);
    }
    return result;
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
