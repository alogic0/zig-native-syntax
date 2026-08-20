const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable_dummy_backend = b.option(
        bool,
        "backend-dummy",
        "Enable the test-only optional backend used to verify dependency selection",
    ) orelse false;

    const native_syntax = b.addModule("native_syntax", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const render_zig = b.addExecutable(.{
        .name = "render-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/render_zig.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_render_zig = b.addRunArtifact(render_zig);
    run_render_zig.addPassthruArgs();

    const render_zig_step = b.step(
        "render-zig",
        "Render a Zig source file as highlighted HTML",
    );
    render_zig_step.dependOn(&run_render_zig.step);

    const unit_tests = b.addTest(.{
        .root_module = native_syntax,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const public_api_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/public_api.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_public_api_tests = b.addRunArtifact(public_api_tests);

    const html_property_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/html_properties.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_html_property_tests = b.addRunArtifact(html_property_tests);

    const zig_corpus_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/zig_corpus.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_zig_corpus_tests = b.addRunArtifact(zig_corpus_tests);

    const render_zig_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/render_zig.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_render_zig_tests = b.addRunArtifact(render_zig_tests);

    const core_only_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/core_only.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_core_only_tests = b.addRunArtifact(core_only_tests);

    const run_dummy_backend_tests: ?*std.Build.Step.Run = if (enable_dummy_backend) enabled: {
        const dependency = b.lazyDependency("phase4_dummy_syntax", .{
            .target = target,
            .optimize = optimize,
            .enabled = true,
        }) orelse return;

        const dummy_backend = b.addModule("native_syntax_dummy", .{
            .root_source_file = b.path("src/optional/dummy.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "dummy_syntax", .module = dependency.module("dummy_syntax") },
            },
        });
        const dummy_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/optional_dummy.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_dummy", .module = dummy_backend },
                },
            }),
        });
        break :enabled b.addRunArtifact(dummy_backend_tests);
    } else null;

    const test_step = b.step("test", "Run the native syntax highlighting tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_public_api_tests.step);
    test_step.dependOn(&run_html_property_tests.step);
    test_step.dependOn(&run_zig_corpus_tests.step);
    test_step.dependOn(&run_render_zig_tests.step);
    test_step.dependOn(&run_core_only_tests.step);
    if (run_dummy_backend_tests) |run| test_step.dependOn(&run.step);
}
