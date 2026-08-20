const std = @import("std");

pub fn build(b: *std.Build) !void {
    const enabled = b.option(
        bool,
        "enabled",
        "Confirm that the parent explicitly enabled this test dependency",
    ) orelse false;
    if (!enabled) return error.DummyDependencyLoadedWithoutOptIn;

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    _ = b.addModule("dummy_syntax", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
}
