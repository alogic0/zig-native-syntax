const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable_dummy_backend = b.option(
        bool,
        "backend-dummy",
        "Enable the test-only optional backend used to verify dependency selection",
    ) orelse false;
    const enable_ziggy_backend = b.option(
        bool,
        "backend-ziggy",
        "Enable the optional Ziggy document backend",
    ) orelse false;
    const enable_ziggy_schema_backend = b.option(
        bool,
        "backend-ziggy-schema",
        "Enable the optional Ziggy Schema backend",
    ) orelse false;
    const enable_scripty_backend = b.option(
        bool,
        "backend-scripty",
        "Enable the optional Scripty backend",
    ) orelse false;
    const enable_html_backend = b.option(
        bool,
        "backend-html",
        "Enable the optional HTML backend",
    ) orelse false;
    const enable_xml_backend = b.option(
        bool,
        "backend-xml",
        "Enable the optional XML backend",
    ) orelse false;
    const enable_css_backend = b.option(
        bool,
        "backend-css",
        "Enable the optional CSS backend",
    ) orelse false;
    const enable_superhtml_backend = b.option(
        bool,
        "backend-superhtml",
        "Enable the optional composed SuperHTML backend",
    ) orelse false;
    const enable_markdown_backend = b.option(
        bool,
        "backend-markdown",
        "Enable the optional Markdown backend",
    ) orelse false;
    const ziggy_dependency = if (enable_ziggy_backend or enable_ziggy_schema_backend)
        b.lazyDependency("ziggy", .{
            .target = target,
            .optimize = optimize,
        }) orelse return
    else
        null;
    const scripty_dependency = if (enable_scripty_backend or enable_superhtml_backend)
        b.lazyDependency("scripty", .{
            .target = target,
            .optimize = optimize,
            .tracy = false,
        }) orelse return
    else
        null;
    const superhtml_dependency = if (enable_html_backend or
        enable_xml_backend or
        enable_css_backend or
        enable_superhtml_backend)
        b.lazyDependency("superhtml", .{
            .target = target,
            .optimize = optimize,
            .tokenizers_only = true,
        }) orelse return
    else
        null;
    const markdown_dependency = if (enable_markdown_backend)
        b.lazyDependency("markdown_parser", .{
            .target = target,
            .optimize = optimize,
        }) orelse return
    else
        null;

    const native_syntax = b.addModule("native_syntax", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const html_markup_module = if (enable_html_backend or
        enable_xml_backend or
        enable_superhtml_backend)
        b.createModule(.{
            .root_source_file = b.path("src/optional/html_markup.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "superhtml_html", .module = superhtml_dependency.?.module("html-tokenizer") },
            },
        })
    else
        null;
    const scripty_backend_module = if (scripty_dependency) |dependency|
        b.addModule("native_syntax_scripty", .{
            .root_source_file = b.path("src/optional/scripty.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "scripty", .module = dependency.module("scripty") },
            },
        })
    else
        null;

    const zig_preview_backend = b.addModule("zig_preview_backend", .{
        .root_source_file = b.path("tools/zig_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "native_syntax", .module = native_syntax },
        },
    });
    const zig_preview = addPreviewTool(b, .{
        .command_name = "render-zig",
        .display_name = "Zig",
        .language_class = "language-zig",
        .sample_path = "source.zig",
        .backend = zig_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const bash_preview_backend = b.addModule("bash_preview_backend", .{
        .root_source_file = b.path("tools/bash_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "native_syntax", .module = native_syntax },
        },
    });
    const bash_preview = addPreviewTool(b, .{
        .command_name = "render-bash",
        .display_name = "Bash",
        .language_class = "language-bash",
        .sample_path = "source.sh",
        .backend = bash_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const rust_preview_backend = b.addModule("rust_preview_backend", .{
        .root_source_file = b.path("tools/rust_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "native_syntax", .module = native_syntax },
        },
    });
    const rust_preview = addPreviewTool(b, .{
        .command_name = "render-rust",
        .display_name = "Rust",
        .language_class = "language-rust",
        .sample_path = "source.rs",
        .backend = rust_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const json_preview_backend = b.addModule("json_preview_backend", .{
        .root_source_file = b.path("tools/json_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "native_syntax", .module = native_syntax },
        },
    });
    const json_preview = addPreviewTool(b, .{
        .command_name = "render-json",
        .display_name = "JSON",
        .language_class = "language-json",
        .sample_path = "source.json",
        .backend = json_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const diff_preview_backend = b.addModule("diff_preview_backend", .{
        .root_source_file = b.path("tools/diff_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "native_syntax", .module = native_syntax },
        },
    });
    const diff_preview = addPreviewTool(b, .{
        .command_name = "render-diff",
        .display_name = "Diff",
        .language_class = "language-diff",
        .sample_path = "source.diff",
        .backend = diff_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const toml_preview_backend = b.addModule("toml_preview_backend", .{
        .root_source_file = b.path("tools/toml_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const toml_preview = addPreviewTool(b, .{
        .command_name = "render-toml",
        .display_name = "TOML",
        .language_class = "language-toml",
        .sample_path = "source.toml",
        .backend = toml_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const dockerfile_preview_backend = b.addModule("dockerfile_preview_backend", .{
        .root_source_file = b.path("tools/dockerfile_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const dockerfile_preview = addPreviewTool(b, .{
        .command_name = "render-dockerfile",
        .display_name = "Dockerfile",
        .language_class = "language-dockerfile",
        .sample_path = "Dockerfile",
        .backend = dockerfile_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const python_preview_backend = b.addModule("python_preview_backend", .{
        .root_source_file = b.path("tools/python_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const python_preview = addPreviewTool(b, .{
        .command_name = "render-python",
        .display_name = "Python",
        .language_class = "language-python",
        .sample_path = "source.py",
        .backend = python_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const sql_preview_backend = b.addModule("sql_preview_backend", .{
        .root_source_file = b.path("tools/sql_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const sql_preview = addPreviewTool(b, .{
        .command_name = "render-sql",
        .display_name = "SQL",
        .language_class = "language-sql",
        .sample_path = "source.sql",
        .backend = sql_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const c_preview_backend = b.addModule("c_preview_backend", .{
        .root_source_file = b.path("tools/c_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const c_preview = addPreviewTool(b, .{
        .command_name = "render-c",
        .display_name = "C",
        .language_class = "language-c",
        .sample_path = "source.c",
        .backend = c_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const javascript_preview_backend = b.addModule("javascript_preview_backend", .{
        .root_source_file = b.path("tools/javascript_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const javascript_preview = addPreviewTool(b, .{
        .command_name = "render-javascript",
        .display_name = "JavaScript",
        .language_class = "language-javascript",
        .sample_path = "source.js",
        .backend = javascript_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const typescript_preview_backend = b.addModule("typescript_preview_backend", .{
        .root_source_file = b.path("tools/typescript_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const typescript_preview = addPreviewTool(b, .{
        .command_name = "render-typescript",
        .display_name = "TypeScript",
        .language_class = "language-typescript",
        .sample_path = "source.ts",
        .backend = typescript_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });

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

    const zig_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/zig_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_zig_conformance_tests = b.addRunArtifact(zig_conformance_tests);

    const bash_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/bash_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_bash_conformance_tests = b.addRunArtifact(bash_conformance_tests);

    const rust_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/rust_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_rust_conformance_tests = b.addRunArtifact(rust_conformance_tests);

    const json_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/json_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_json_conformance_tests = b.addRunArtifact(json_conformance_tests);

    const diff_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/diff_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
            },
        }),
    });
    const run_diff_conformance_tests = b.addRunArtifact(diff_conformance_tests);

    const toml_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/toml_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_toml_conformance_tests = b.addRunArtifact(toml_conformance_tests);

    const dockerfile_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/dockerfile_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_dockerfile_conformance_tests = b.addRunArtifact(dockerfile_conformance_tests);

    const python_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/python_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_python_conformance_tests = b.addRunArtifact(python_conformance_tests);

    const sql_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/sql_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_sql_conformance_tests = b.addRunArtifact(sql_conformance_tests);

    const c_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/c_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_c_conformance_tests = b.addRunArtifact(c_conformance_tests);

    const javascript_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/javascript_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_javascript_conformance_tests = b.addRunArtifact(javascript_conformance_tests);

    const typescript_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/typescript_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_typescript_conformance_tests = b.addRunArtifact(typescript_conformance_tests);

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

    const run_superhtml_api_tests: ?*std.Build.Step.Run = if (superhtml_dependency) |dependency| enabled: {
        const api_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/superhtml_api.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "superhtml_html", .module = dependency.module("html-tokenizer") },
                    .{ .name = "superhtml_css", .module = dependency.module("css-tokenizer") },
                    .{ .name = "superhtml_template", .module = dependency.module("template-syntax") },
                },
            }),
        });
        break :enabled b.addRunArtifact(api_tests);
    } else null;

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

    const ziggy_backend_runs: ?OptionalBackendRuns = if (enable_ziggy_backend) enabled: {
        const dependency = ziggy_dependency.?;

        const ziggy_backend = b.addModule("native_syntax_ziggy", .{
            .root_source_file = b.path("src/optional/ziggy.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "ziggy", .module = dependency.module("ziggy") },
            },
        });
        const ziggy_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/ziggy_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_ziggy", .module = ziggy_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-ziggy",
            .display_name = "Ziggy",
            .language_class = "language-ziggy",
            .sample_path = "source.ziggy",
            .backend = ziggy_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(ziggy_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const ziggy_schema_backend_runs: ?OptionalBackendRuns = if (enable_ziggy_schema_backend) enabled: {
        const dependency = ziggy_dependency.?;

        const ziggy_schema_backend = b.addModule("native_syntax_ziggy_schema", .{
            .root_source_file = b.path("src/optional/ziggy_schema.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "ziggy", .module = dependency.module("ziggy") },
            },
        });
        const ziggy_schema_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/ziggy_schema_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_ziggy_schema", .module = ziggy_schema_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-ziggy-schema",
            .display_name = "Ziggy Schema",
            .language_class = "language-ziggy-schema",
            .sample_path = "source.ziggy-schema",
            .backend = ziggy_schema_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(ziggy_schema_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const scripty_backend_runs: ?OptionalBackendRuns = if (enable_scripty_backend) enabled: {
        const scripty_backend = scripty_backend_module.?;
        const scripty_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/scripty_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_scripty", .module = scripty_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-scripty",
            .display_name = "Scripty",
            .language_class = "language-scripty",
            .sample_path = "source.scripty",
            .backend = scripty_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(scripty_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const html_backend_runs: ?OptionalBackendRuns = if (enable_html_backend) enabled: {
        const html_backend = b.addModule("native_syntax_html", .{
            .root_source_file = b.path("src/optional/html.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "native_syntax_html_markup", .module = html_markup_module.? },
            },
        });
        const html_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/html_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_html", .module = html_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-html",
            .display_name = "HTML",
            .language_class = "language-html",
            .sample_path = "source.html",
            .backend = html_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(html_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const xml_backend_runs: ?OptionalBackendRuns = if (enable_xml_backend) enabled: {
        const xml_backend = b.addModule("native_syntax_xml", .{
            .root_source_file = b.path("src/optional/xml.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "native_syntax_html_markup", .module = html_markup_module.? },
            },
        });
        const xml_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/xml_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_xml", .module = xml_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-xml",
            .display_name = "XML",
            .language_class = "language-xml",
            .sample_path = "source.xml",
            .backend = xml_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(xml_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const css_backend_runs: ?OptionalBackendRuns = if (enable_css_backend) enabled: {
        const dependency = superhtml_dependency.?;
        const css_backend = b.addModule("native_syntax_css", .{
            .root_source_file = b.path("src/optional/css.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "superhtml_css", .module = dependency.module("css-tokenizer") },
            },
        });
        const css_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/css_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_css", .module = css_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-css",
            .display_name = "CSS",
            .language_class = "language-css",
            .sample_path = "source.css",
            .backend = css_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(css_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const superhtml_backend_runs: ?OptionalBackendRuns = if (enable_superhtml_backend) enabled: {
        const dependency = superhtml_dependency.?;
        const superhtml_backend = b.addModule("native_syntax_superhtml", .{
            .root_source_file = b.path("src/optional/superhtml.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "native_syntax_scripty", .module = scripty_backend_module.? },
                .{ .name = "native_syntax_html_markup", .module = html_markup_module.? },
                .{ .name = "superhtml_html", .module = dependency.module("html-tokenizer") },
                .{ .name = "superhtml_template", .module = dependency.module("template-syntax") },
            },
        });
        const superhtml_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/superhtml_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_superhtml", .module = superhtml_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-superhtml",
            .display_name = "SuperHTML",
            .language_class = "language-superhtml",
            .sample_path = "source.shtml",
            .backend = superhtml_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(superhtml_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const markdown_backend_runs: ?OptionalBackendRuns = if (markdown_dependency) |dependency| enabled: {
        const markdown_backend = b.addModule("native_syntax_markdown", .{
            .root_source_file = b.path("src/optional/markdown.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "markdown", .module = dependency.module("markdown") },
            },
        });
        const markdown_backend_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/markdown_backend.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_markdown", .module = markdown_backend },
                },
            }),
        });
        const preview = addPreviewTool(b, .{
            .command_name = "render-markdown",
            .display_name = "Markdown",
            .language_class = "language-markdown",
            .sample_path = "source.md",
            .backend = markdown_backend,
            .native_syntax = native_syntax,
            .target = target,
            .optimize = optimize,
        });
        break :enabled .{
            .backend_test_run = b.addRunArtifact(markdown_backend_tests),
            .preview_test_run = preview.test_run,
        };
    } else null;

    const test_step = b.step("test", "Run the native syntax highlighting tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_public_api_tests.step);
    test_step.dependOn(&run_html_property_tests.step);
    test_step.dependOn(&run_zig_corpus_tests.step);
    test_step.dependOn(&run_zig_conformance_tests.step);
    test_step.dependOn(&zig_preview.test_run.step);
    test_step.dependOn(&run_bash_conformance_tests.step);
    test_step.dependOn(&bash_preview.test_run.step);
    test_step.dependOn(&run_rust_conformance_tests.step);
    test_step.dependOn(&rust_preview.test_run.step);
    test_step.dependOn(&run_json_conformance_tests.step);
    test_step.dependOn(&json_preview.test_run.step);
    test_step.dependOn(&run_diff_conformance_tests.step);
    test_step.dependOn(&diff_preview.test_run.step);
    test_step.dependOn(&run_toml_conformance_tests.step);
    test_step.dependOn(&toml_preview.test_run.step);
    test_step.dependOn(&run_dockerfile_conformance_tests.step);
    test_step.dependOn(&dockerfile_preview.test_run.step);
    test_step.dependOn(&run_python_conformance_tests.step);
    test_step.dependOn(&python_preview.test_run.step);
    test_step.dependOn(&run_sql_conformance_tests.step);
    test_step.dependOn(&sql_preview.test_run.step);
    test_step.dependOn(&run_c_conformance_tests.step);
    test_step.dependOn(&c_preview.test_run.step);
    test_step.dependOn(&run_javascript_conformance_tests.step);
    test_step.dependOn(&javascript_preview.test_run.step);
    test_step.dependOn(&run_typescript_conformance_tests.step);
    test_step.dependOn(&typescript_preview.test_run.step);
    test_step.dependOn(&run_core_only_tests.step);
    if (run_superhtml_api_tests) |run| test_step.dependOn(&run.step);
    if (run_dummy_backend_tests) |run| test_step.dependOn(&run.step);
    if (ziggy_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (ziggy_schema_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (scripty_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (html_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (xml_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (css_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (superhtml_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    if (markdown_backend_runs) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
}

const OptionalBackendRuns = struct {
    backend_test_run: *std.Build.Step.Run,
    preview_test_run: *std.Build.Step.Run,
};

const PreviewOptions = struct {
    command_name: []const u8,
    display_name: []const u8,
    language_class: []const u8,
    sample_path: []const u8,
    backend: *std.Build.Module,
    native_syntax: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
};

const PreviewTool = struct {
    test_run: *std.Build.Step.Run,
};

fn addPreviewTool(b: *std.Build, options: PreviewOptions) PreviewTool {
    const config = b.addOptions();
    config.addOption([]const u8, "command_name", options.command_name);
    config.addOption([]const u8, "display_name", options.display_name);
    config.addOption([]const u8, "language_class", options.language_class);
    config.addOption([]const u8, "sample_path", options.sample_path);

    const executable = b.addExecutable(.{
        .name = options.command_name,
        .root_module = createPreviewModule(b, options, config),
    });
    const run = b.addRunArtifact(executable);
    run.addPassthruArgs();

    const render_step = b.step(
        options.command_name,
        b.fmt("Render {s} source as highlighted HTML", .{options.display_name}),
    );
    render_step.dependOn(&run.step);

    const tests = b.addTest(.{
        .root_module = createPreviewModule(b, options, config),
    });
    return .{ .test_run = b.addRunArtifact(tests) };
}

fn createPreviewModule(
    b: *std.Build,
    options: PreviewOptions,
    config: *std.Build.Step.Options,
) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("tools/render_source.zig"),
        .target = options.target,
        .optimize = options.optimize,
        .imports = &.{
            .{ .name = "native_syntax", .module = options.native_syntax },
            .{ .name = "preview_backend", .module = options.backend },
        },
    });
    module.addOptions("preview_config", config);
    return module;
}
