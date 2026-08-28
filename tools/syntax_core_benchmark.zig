const std = @import("std");
const syntax = @import("native_syntax");
const bash_lexical = @import("bash_lexical");
const javascript_lexical = @import("javascript_lexical");
const rust_lexical = @import("rust_lexical");
const benchmark = @import("benchmark_support.zig");

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
    try benchmarkCase(init, stdout, .{
        .name = "Rust",
        .path = "tests/corpus/rust/complete.rs",
        .lexical = rust_lexical.backend,
        .structural = syntax.languages.rust.backend,
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

    const lexical_allocations = try benchmark.measureAllocations(init.gpa, case.lexical, source);
    const structural_allocations = try benchmark.measureAllocations(init.gpa, case.structural, source);
    const lexical = try benchmark.measureTime(init, case.lexical, source, iterations);
    const structural = try benchmark.measureTime(init, case.structural, source, iterations);

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
        benchmark.throughput(source.len * iterations, lexical.elapsed_ns),
        lexical.capture_count,
        lexical_allocations.calls,
        lexical_allocations.requested_bytes,
        lexical_allocations.peak_bytes,
        benchmark.throughput(source.len * iterations, structural.elapsed_ns),
        structural.capture_count,
        structural_allocations.calls,
        structural_allocations.requested_bytes,
        structural_allocations.peak_bytes,
        benchmark.ratio(lexical.elapsed_ns, structural.elapsed_ns),
        lexical.checksum +% structural.checksum,
    });
}
