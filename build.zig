const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const enable_dummy_backend = b.option(
        bool,
        "backend-dummy",
        "Enable the test-only optional backend used to verify dependency selection",
    ) orelse false;
    const enable_external_backends = b.option(
        bool,
        "external-backends",
        "Enable all external syntax backends unless individually overridden",
    ) orelse true;
    const size_analysis_exclusions = b.option(
        []const u8,
        "size-analysis-exclude-backends",
        "Comma-separated core backends omitted only for code-size analysis",
    ) orelse "";
    const size_analysis_inclusions = b.option(
        []const u8,
        "size-analysis-include-backends",
        "Comma-separated experimental core backends included only for code-size analysis",
    ) orelse "";
    const enable_ziggy_backend = b.option(
        bool,
        "backend-ziggy",
        "Enable the external Ziggy document backend",
    ) orelse enable_external_backends;
    const enable_ziggy_schema_backend = b.option(
        bool,
        "backend-ziggy-schema",
        "Enable the external Ziggy Schema backend",
    ) orelse enable_external_backends;
    const enable_scripty_backend = b.option(
        bool,
        "backend-scripty",
        "Enable the external Scripty backend",
    ) orelse enable_external_backends;
    const enable_html_backend = b.option(
        bool,
        "backend-html",
        "Enable the external HTML backend",
    ) orelse enable_external_backends;
    const enable_xml_backend = b.option(
        bool,
        "backend-xml",
        "Enable the external XML backend",
    ) orelse enable_external_backends;
    const enable_css_backend = b.option(
        bool,
        "backend-css",
        "Enable the external CSS backend",
    ) orelse enable_external_backends;
    const enable_superhtml_backend = b.option(
        bool,
        "backend-superhtml",
        "Enable the external composed SuperHTML backend",
    ) orelse enable_external_backends;
    const enable_markdown_backend = b.option(
        bool,
        "backend-markdown",
        "Enable the external Markdown backend",
    ) orelse enable_external_backends;
    const ziggy_dependency = if (enable_ziggy_backend or enable_ziggy_schema_backend)
        b.dependency("ziggy", .{
            .target = target,
            .optimize = optimize,
        })
    else
        null;
    const scripty_dependency = if (enable_scripty_backend or enable_superhtml_backend)
        b.dependency("scripty", .{
            .target = target,
            .optimize = optimize,
            .tracy = false,
        })
    else
        null;
    const superhtml_dependency = if (enable_html_backend or
        enable_xml_backend or
        enable_css_backend or
        enable_superhtml_backend)
        b.dependency("superhtml", .{
            .target = target,
            .optimize = optimize,
            .tokenizers_only = true,
        })
    else
        null;
    const markdown_dependency = if (enable_markdown_backend)
        b.dependency("markdown_parser", .{
            .target = target,
            .optimize = optimize,
        })
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
    const yaml_preview_backend = b.addModule("yaml_preview_backend", .{
        .root_source_file = b.path("tools/yaml_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const yaml_preview = addPreviewTool(b, .{
        .command_name = "render-yaml",
        .display_name = "YAML",
        .language_class = "language-yaml",
        .sample_path = "source.yaml",
        .backend = yaml_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const hcl_preview_backend = b.addModule("hcl_preview_backend", .{
        .root_source_file = b.path("tools/hcl_preview_backend.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const hcl_preview = addPreviewTool(b, .{
        .command_name = "render-hcl",
        .display_name = "HCL",
        .language_class = "language-hcl",
        .sample_path = "source.hcl",
        .backend = hcl_preview_backend,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const make_runs = addCoreLanguage(b, native_syntax, target, optimize, .{
        .name = "make",
        .display_name = "Make",
        .sample_path = "source.mk",
    });
    const cmake_runs = addCoreLanguage(b, native_syntax, target, optimize, .{
        .name = "cmake",
        .display_name = "CMake",
        .sample_path = "CMakeLists.txt",
    });
    const java_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "java", .display_name = "Java", .sample_path = "source.java" });
    const c_sharp_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "c-sharp", .file_stem = "c_sharp", .display_name = "C#", .sample_path = "source.cs" });
    const cpp_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "cpp", .display_name = "C++", .sample_path = "source.cpp" });
    const go_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "go", .display_name = "Go", .sample_path = "source.go" });
    const powershell_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "powershell", .display_name = "PowerShell", .sample_path = "source.ps1" });
    const php_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "php", .display_name = "PHP", .sample_path = "source.php" });
    const lua_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "lua", .display_name = "Lua", .sample_path = "source.lua" });
    const kotlin_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "kotlin", .display_name = "Kotlin", .sample_path = "source.kt" });
    const ruby_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "ruby", .display_name = "Ruby", .sample_path = "source.rb" });
    const swift_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "swift", .display_name = "Swift", .sample_path = "source.swift" });
    const assembly_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "asm", .file_stem = "assembly", .display_name = "Assembly", .sample_path = "source.s" });
    const nasm_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "nasm", .display_name = "NASM", .sample_path = "source.nasm" });
    const objc_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "objc", .display_name = "Objective-C", .sample_path = "source.m" });
    const vue_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "vue", .display_name = "Vue", .sample_path = "source.vue" });
    const astro_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "astro", .display_name = "Astro", .sample_path = "source.astro" });
    const jsdoc_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "jsdoc", .display_name = "JSDoc", .sample_path = "source.jsdoc" });
    const regex_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "regex", .display_name = "Regular expression", .sample_path = "source.regex" });
    const proto_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "proto", .display_name = "Protocol Buffers", .sample_path = "source.proto" });
    const kdl_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "kdl", .display_name = "KDL", .sample_path = "source.kdl" });
    const nix_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "nix", .display_name = "Nix", .sample_path = "source.nix" });
    const fish_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "fish", .display_name = "Fish", .sample_path = "source.fish" });
    const nu_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "nu", .display_name = "Nushell", .sample_path = "source.nu" });
    const awk_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "awk", .display_name = "AWK", .sample_path = "source.awk" });
    const ssh_config_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "ssh-config", .file_stem = "ssh_config", .display_name = "SSH config", .sample_path = "config" });
    const gitcommit_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "gitcommit", .display_name = "Git commit", .sample_path = "COMMIT_EDITMSG" });
    const git_rebase_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "git-rebase", .file_stem = "git_rebase", .display_name = "Git rebase", .sample_path = "git-rebase-todo" });
    const po_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "po", .display_name = "Gettext PO", .sample_path = "source.po" });
    const rst_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "rst", .display_name = "reStructuredText", .sample_path = "source.rst" });
    const latex_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "latex", .display_name = "LaTeX", .sample_path = "source.tex" });
    const typst_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "typst", .display_name = "Typst", .sample_path = "source.typ" });
    const org_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "org", .display_name = "Org Mode", .sample_path = "source.org" });
    const dtd_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "dtd", .display_name = "DTD", .sample_path = "source.dtd" });
    const mail_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "mail", .display_name = "E-mail", .sample_path = "source.eml" });
    const hurl_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "hurl", .display_name = "Hurl", .sample_path = "source.hurl" });
    const ninja_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "ninja", .display_name = "Ninja", .sample_path = "build.ninja" });
    const rpmspec_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "rpmspec", .display_name = "RPM spec", .sample_path = "source.spec" });
    const rpmbash_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "rpmbash", .display_name = "RPM Bash", .sample_path = "source.sh" });
    const gdscript_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "gdscript", .display_name = "GDScript", .sample_path = "source.gd" });
    const perl_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "perl", .display_name = "Perl", .sample_path = "source.pl" });
    const elixir_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "elixir", .display_name = "Elixir", .sample_path = "source.ex" });
    const fsharp_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "fsharp", .display_name = "F#", .sample_path = "source.fs" });
    const ocaml_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "ocaml", .display_name = "OCaml", .sample_path = "source.ml" });
    const haskell_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "haskell", .display_name = "Haskell", .sample_path = "source.hs" });
    const gleam_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "gleam", .display_name = "Gleam", .sample_path = "source.gleam" });
    const commonlisp_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "commonlisp", .display_name = "Common Lisp", .sample_path = "source.lisp" });
    const scheme_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "scheme", .display_name = "Scheme", .sample_path = "source.scm" });
    const julia_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "julia", .display_name = "Julia", .sample_path = "source.jl" });
    const elm_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "elm", .display_name = "Elm", .sample_path = "source.elm" });
    const purescript_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "purescript", .display_name = "PureScript", .sample_path = "source.purs" });
    const nim_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "nim", .display_name = "Nim", .sample_path = "source.nim" });
    const d_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "d", .display_name = "D", .sample_path = "source.d" });
    const v_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "v", .display_name = "V", .sample_path = "source.v" });
    const odin_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "odin", .display_name = "Odin", .sample_path = "source.odin" });
    const c3_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "c3", .display_name = "C3", .sample_path = "source.c3" });
    const systemverilog_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "systemverilog", .display_name = "SystemVerilog", .sample_path = "source.sv" });
    const llvm_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "llvm", .display_name = "LLVM IR", .sample_path = "source.ll" });
    const mlir_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "mlir", .display_name = "MLIR", .sample_path = "source.mlir" });
    const tablegen_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "tablegen", .display_name = "TableGen", .sample_path = "source.td" });
    const fortran_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "fortran", .display_name = "Fortran", .sample_path = "source.f90" });
    const pdll_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "pdll", .display_name = "PDLL", .sample_path = "source.pdll" });
    const batch_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "batch", .display_name = "Windows Batch", .sample_path = "source.bat" });
    const starlark_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "starlark", .display_name = "Starlark", .sample_path = "source.bzl" });
    const shell_session_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "shell-session", .file_stem = "shell_session", .display_name = "Shell session", .sample_path = "session.txt" });
    const openscad_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "openscad", .display_name = "OpenSCAD", .sample_path = "source.scad" });
    const nickel_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "nickel", .display_name = "Nickel", .sample_path = "source.ncl" });
    const hare_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "hare", .display_name = "Hare", .sample_path = "source.ha" });
    const agda_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "agda", .display_name = "Agda", .sample_path = "source.agda" });
    const query_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "query", .display_name = "Tree-sitter Query", .sample_path = "highlights.scm" });
    const vim_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "vim", .display_name = "Vimscript", .sample_path = "source.vim" });
    const uxntal_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "uxntal", .display_name = "Uxntal", .sample_path = "source.tal" });
    const comment_runs = addCoreLanguage(b, native_syntax, target, optimize, .{ .name = "comment", .display_name = "Comment tags", .sample_path = "comment.txt" });

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

    const adversarial_backend_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/adversarial_backends.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_adversarial_backend_tests = b.addRunArtifact(adversarial_backend_tests);

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

    const benchmark_native_syntax = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    const bash_lexical_baseline = b.createModule(.{
        .root_source_file = b.path("tools/baselines/bash_lexical.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .imports = &.{.{ .name = "native_syntax", .module = benchmark_native_syntax }},
    });
    const javascript_lexical_baseline = b.createModule(.{
        .root_source_file = b.path("tools/baselines/javascript_lexical.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .imports = &.{.{ .name = "native_syntax", .module = benchmark_native_syntax }},
    });
    const rust_lexical_baseline = b.createModule(.{
        .root_source_file = b.path("tools/baselines/rust_lexical.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .imports = &.{.{ .name = "native_syntax", .module = benchmark_native_syntax }},
    });
    const syntax_core_benchmark = b.addExecutable(.{
        .name = "benchmark-syntax-core",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/syntax_core_benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "native_syntax", .module = benchmark_native_syntax },
                .{ .name = "bash_lexical", .module = bash_lexical_baseline },
                .{ .name = "javascript_lexical", .module = javascript_lexical_baseline },
                .{ .name = "rust_lexical", .module = rust_lexical_baseline },
            },
        }),
    });
    const run_syntax_core_benchmark = b.addRunArtifact(syntax_core_benchmark);
    run_syntax_core_benchmark.addPassthruArgs();
    const syntax_core_benchmark_step = b.step(
        "benchmark-syntax-core",
        "Compare structural backends with their former lexical scanners",
    );
    syntax_core_benchmark_step.dependOn(&run_syntax_core_benchmark.step);

    addMlBenchmark(b, target, .ReleaseFast, "benchmark-ml", "benchmark-ml-fast");
    addMlBenchmark(b, target, .ReleaseSmall, "benchmark-ml-small", "benchmark-ml-small");

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

    const yaml_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/yaml_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_yaml_conformance_tests = b.addRunArtifact(yaml_conformance_tests);

    const hcl_conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/hcl_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    const run_hcl_conformance_tests = b.addRunArtifact(hcl_conformance_tests);

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

    const registry_options = b.addOptions();
    registry_options.addOption(bool, "ziggy", enable_ziggy_backend);
    registry_options.addOption(bool, "ziggy_schema", enable_ziggy_schema_backend);
    registry_options.addOption(bool, "scripty", enable_scripty_backend);
    registry_options.addOption(bool, "html", enable_html_backend);
    registry_options.addOption(bool, "xml", enable_xml_backend);
    registry_options.addOption(bool, "css", enable_css_backend);
    registry_options.addOption(bool, "superhtml", enable_superhtml_backend);
    registry_options.addOption(bool, "markdown", enable_markdown_backend);
    registry_options.addOption([]const u8, "size_analysis_exclusions", size_analysis_exclusions);
    registry_options.addOption([]const u8, "size_analysis_inclusions", size_analysis_inclusions);

    const configured_registry = b.addModule("native_syntax_registry", .{
        .root_source_file = b.path("src/configured_registry.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    configured_registry.addOptions("registry_options", registry_options);
    if (enable_ziggy_backend) configured_registry.addImport("native_syntax_ziggy", b.modules.get("native_syntax_ziggy").?);
    if (enable_ziggy_schema_backend) configured_registry.addImport("native_syntax_ziggy_schema", b.modules.get("native_syntax_ziggy_schema").?);
    if (enable_scripty_backend) configured_registry.addImport("native_syntax_scripty", b.modules.get("native_syntax_scripty").?);
    if (enable_html_backend) configured_registry.addImport("native_syntax_html", b.modules.get("native_syntax_html").?);
    if (enable_xml_backend) configured_registry.addImport("native_syntax_xml", b.modules.get("native_syntax_xml").?);
    if (enable_css_backend) configured_registry.addImport("native_syntax_css", b.modules.get("native_syntax_css").?);
    if (enable_superhtml_backend) configured_registry.addImport("native_syntax_superhtml", b.modules.get("native_syntax_superhtml").?);
    if (enable_markdown_backend) configured_registry.addImport("native_syntax_markdown", b.modules.get("native_syntax_markdown").?);

    const configured_registry_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/configured_registry.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "native_syntax_registry", .module = configured_registry },
            },
        }),
    });
    const run_configured_registry_tests = b.addRunArtifact(configured_registry_tests);

    const complete_registry_enabled = enable_ziggy_backend and
        enable_ziggy_schema_backend and enable_scripty_backend and
        enable_html_backend and enable_xml_backend and enable_css_backend and
        enable_superhtml_backend and enable_markdown_backend and
        size_analysis_exclusions.len == 0 and size_analysis_inclusions.len == 0;
    const support_matrix_check: ?*std.Build.Step.Run = if (complete_registry_enabled) enabled: {
        const generator = b.addExecutable(.{
            .name = "generate-support-matrix",
            .root_module = b.createModule(.{
                .root_source_file = b.path("tools/support_matrix.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "native_syntax", .module = native_syntax },
                    .{ .name = "native_syntax_registry", .module = configured_registry },
                },
            }),
        });

        const generate = b.addRunArtifact(generator);
        const generated = generate.captureStdOut(.{});
        const update = b.addUpdateSourceFiles();
        update.addCopyFileToSource(generated, "docs/supported-languages.md");
        update.step.dependOn(&generate.step);
        const update_step = b.step(
            "update-support-matrix",
            "Regenerate the supported-language matrix from the configured registry",
        );
        update_step.dependOn(&update.step);

        const check = b.addRunArtifact(generator);
        check.addArg("--check");
        check.addFileArg(b.path("docs/supported-languages.md"));
        break :enabled check;
    } else null;

    const analysis_registry_options = b.addOptions();
    inline for (.{ "ziggy", "ziggy_schema", "scripty", "html", "xml", "css", "superhtml", "markdown" }) |name| {
        analysis_registry_options.addOption(bool, name, false);
    }
    analysis_registry_options.addOption([]const u8, "size_analysis_exclusions", "");
    analysis_registry_options.addOption([]const u8, "size_analysis_inclusions", "dtd");
    const analysis_registry = b.createModule(.{
        .root_source_file = b.path("src/configured_registry.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    analysis_registry.addOptions("registry_options", analysis_registry_options);
    const configured_registry_analysis_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/configured_registry_analysis.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "native_syntax_registry", .module = analysis_registry },
            },
        }),
    });
    const run_configured_registry_analysis_tests = b.addRunArtifact(configured_registry_analysis_tests);

    const registry_fuzz_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/registry_fuzz.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "native_syntax", .module = native_syntax },
                .{ .name = "native_syntax_registry", .module = configured_registry },
            },
        }),
    });
    const run_registry_fuzz_tests = b.addRunArtifact(registry_fuzz_tests);
    const fuzz_registry_step = b.step(
        "fuzz-registry",
        "Fuzz every configured syntax backend",
    );
    fuzz_registry_step.dependOn(&run_registry_fuzz_tests.step);

    const optional_test_step = b.step(
        "test-optional",
        "Run tests for the enabled optional syntax backends",
    );
    optional_test_step.dependOn(&run_configured_registry_tests.step);
    optional_test_step.dependOn(&run_registry_fuzz_tests.step);
    if (support_matrix_check) |check| optional_test_step.dependOn(&check.step);
    if (run_superhtml_api_tests) |run| optional_test_step.dependOn(&run.step);
    if (run_dummy_backend_tests) |run| optional_test_step.dependOn(&run.step);
    if (ziggy_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (ziggy_schema_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (scripty_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (html_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (xml_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (css_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (superhtml_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }
    if (markdown_backend_runs) |runs| {
        optional_test_step.dependOn(&runs.backend_test_run.step);
        optional_test_step.dependOn(&runs.preview_test_run.step);
    }

    const shared_test_step = b.step(
        "test-shared",
        "Run consolidated shared API and registry tests",
    );
    shared_test_step.dependOn(&run_unit_tests.step);
    shared_test_step.dependOn(&run_public_api_tests.step);
    shared_test_step.dependOn(&run_adversarial_backend_tests.step);
    shared_test_step.dependOn(&run_configured_registry_tests.step);
    shared_test_step.dependOn(&run_configured_registry_analysis_tests.step);
    shared_test_step.dependOn(&run_registry_fuzz_tests.step);
    shared_test_step.dependOn(&run_html_property_tests.step);
    shared_test_step.dependOn(&run_core_only_tests.step);

    const test_step = b.step("test", "Run the native syntax highlighting tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_public_api_tests.step);
    test_step.dependOn(&run_adversarial_backend_tests.step);
    test_step.dependOn(optional_test_step);
    test_step.dependOn(&run_configured_registry_analysis_tests.step);
    test_step.dependOn(&run_registry_fuzz_tests.step);
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
    test_step.dependOn(&run_yaml_conformance_tests.step);
    test_step.dependOn(&yaml_preview.test_run.step);
    test_step.dependOn(&run_hcl_conformance_tests.step);
    test_step.dependOn(&hcl_preview.test_run.step);
    test_step.dependOn(&make_runs.backend_test_run.step);
    test_step.dependOn(&make_runs.preview_test_run.step);
    test_step.dependOn(&cmake_runs.backend_test_run.step);
    test_step.dependOn(&cmake_runs.preview_test_run.step);
    inline for (.{ java_runs, c_sharp_runs, cpp_runs, go_runs, powershell_runs, php_runs, lua_runs, kotlin_runs, ruby_runs, swift_runs, assembly_runs, nasm_runs, objc_runs, vue_runs, astro_runs, jsdoc_runs, regex_runs, proto_runs }) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    inline for (.{ kdl_runs, nix_runs, fish_runs, nu_runs, awk_runs, ssh_config_runs, gitcommit_runs, git_rebase_runs, po_runs, rst_runs, latex_runs, typst_runs, org_runs, dtd_runs, mail_runs, hurl_runs, ninja_runs, rpmspec_runs, rpmbash_runs, gdscript_runs, perl_runs, elixir_runs, fsharp_runs, ocaml_runs, haskell_runs, gleam_runs, commonlisp_runs, scheme_runs, julia_runs, elm_runs, purescript_runs, nim_runs }) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    inline for (.{ d_runs, v_runs, odin_runs, c3_runs, systemverilog_runs, llvm_runs, mlir_runs, tablegen_runs, fortran_runs, pdll_runs, batch_runs, starlark_runs, shell_session_runs, openscad_runs, nickel_runs, hare_runs }) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    inline for (.{ agda_runs, query_runs, vim_runs, uxntal_runs, comment_runs }) |runs| {
        test_step.dependOn(&runs.backend_test_run.step);
        test_step.dependOn(&runs.preview_test_run.step);
    }
    test_step.dependOn(&run_core_only_tests.step);
}

const OptionalBackendRuns = struct {
    backend_test_run: *std.Build.Step.Run,
    preview_test_run: *std.Build.Step.Run,
};

fn addMlBenchmark(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    step_name: []const u8,
    executable_name: []const u8,
) void {
    const benchmark_native_syntax = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    const executable = b.addExecutable(.{
        .name = executable_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("tools/ml_benchmark.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = benchmark_native_syntax }},
        }),
    });
    const run = b.addRunArtifact(executable);
    run.addPassthruArgs();
    const step = b.step(step_name, b.fmt("Benchmark OCaml and F# with {s}", .{@tagName(optimize)}));
    step.dependOn(&run.step);
}

const CoreLanguageOptions = struct {
    name: []const u8,
    file_stem: ?[]const u8 = null,
    display_name: []const u8,
    sample_path: []const u8,
};

fn addCoreLanguage(
    b: *std.Build,
    native_syntax: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: CoreLanguageOptions,
) OptionalBackendRuns {
    const file_stem = options.file_stem orelse options.name;
    const backend_module = b.addModule(b.fmt("{s}_preview_backend", .{options.name}), .{
        .root_source_file = b.path(b.fmt("tools/{s}_preview_backend.zig", .{file_stem})),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
    });
    const preview = addPreviewTool(b, .{
        .command_name = b.fmt("render-{s}", .{options.name}),
        .display_name = options.display_name,
        .language_class = b.fmt("language-{s}", .{options.name}),
        .sample_path = options.sample_path,
        .backend = backend_module,
        .native_syntax = native_syntax,
        .target = target,
        .optimize = optimize,
    });
    const conformance_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("tests/{s}_conformance.zig", .{file_stem})),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "native_syntax", .module = native_syntax }},
        }),
    });
    return .{
        .backend_test_run = b.addRunArtifact(conformance_tests),
        .preview_test_run = preview.test_run,
    };
}

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
