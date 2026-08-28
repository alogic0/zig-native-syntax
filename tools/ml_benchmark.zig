const std = @import("std");
const builtin = @import("builtin");
const syntax = @import("native_syntax");
const benchmark = @import("benchmark_support.zig");

const default_iterations: usize = 1_000;
const default_repetitions: usize = 64;

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const iterations = if (args.len > 1)
        try std.fmt.parseInt(usize, args[1], 10)
    else
        default_iterations;
    const repetitions = if (args.len > 2)
        try std.fmt.parseInt(usize, args[2], 10)
    else
        default_repetitions;
    if (iterations == 0 or repetitions == 0) return error.InvalidArguments;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try benchmarkLanguage(init, stdout, .{
        .name = "OCaml",
        .path = "tests/corpus/ocaml/complete.txt",
        .backend = syntax.languages.ocaml.backend,
    }, iterations, repetitions);
    try benchmarkLanguage(init, stdout, .{
        .name = "F#",
        .path = "tests/corpus/fsharp/complete.txt",
        .backend = syntax.languages.fsharp.backend,
    }, iterations, repetitions);
    try stdout.flush();
}

const Case = struct {
    name: []const u8,
    path: []const u8,
    backend: syntax.Backend,
};

fn benchmarkLanguage(
    init: std.process.Init,
    writer: *std.Io.Writer,
    case: Case,
    iterations: usize,
    repetitions: usize,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        case.path,
        init.gpa,
        .limited(std.math.maxInt(u32)),
    );
    defer init.gpa.free(source);

    try benchmarkCase(writer, init, case, "corpus", source, iterations);

    const repeated = try benchmark.repeatSource(init.gpa, source, repetitions);
    defer init.gpa.free(repeated);
    try benchmarkCase(writer, init, case, "repeated", repeated, iterations);
}

fn benchmarkCase(
    writer: *std.Io.Writer,
    init: std.process.Init,
    case: Case,
    profile: []const u8,
    source: []const u8,
    iterations: usize,
) !void {
    const allocations = try benchmark.measureAllocations(init.gpa, case.backend, source);
    const timing = try benchmark.measureTime(init, case.backend, source, iterations);

    try writer.print(
        \\{s} ML benchmark ({s}, {s})
        \\  source: {s} ({d} bytes, {d} iterations)
        \\  throughput: {d:.2} MiB/s
        \\  latency: {d:.2} ns/iteration
        \\  captures: {d}
        \\  allocations: {d} calls, {d} requested bytes, {d} peak bytes
        \\  checksum: {d}
        \\
    , .{
        case.name,
        @tagName(builtin.mode),
        profile,
        case.path,
        source.len,
        iterations,
        benchmark.throughput(source.len * iterations, timing.elapsed_ns),
        benchmark.latency(timing.elapsed_ns, iterations),
        timing.capture_count,
        allocations.calls,
        allocations.requested_bytes,
        allocations.peak_bytes,
        timing.checksum,
    });
}
