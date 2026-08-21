//! Source-preserving primitives for native syntax highlighting.

const std = @import("std");

const capture = @import("capture.zig");
const backend = @import("backend.zig");

pub const html = @import("html.zig");
pub const composition = @import("composition.zig");
pub const Scope = @import("scope.zig").Scope;
pub const Span = capture.Span;
pub const Capture = capture.Capture;
pub const ValidationError = capture.ValidationError;
pub const Backend = backend.Backend;
pub const BackendInfo = backend.BackendInfo;
pub const BackendKind = backend.BackendKind;
pub const CaptureSink = backend.CaptureSink;
pub const HighlightError = backend.HighlightError;
pub const MetadataError = backend.MetadataError;

pub const languages = struct {
    pub const astro = @import("languages/astro.zig");
    pub const bash = @import("languages/bash.zig");
    pub const assembly = @import("languages/assembly.zig");
    pub const c = @import("languages/c.zig");
    pub const cmake = @import("languages/cmake.zig");
    pub const cpp = @import("languages/cpp.zig");
    pub const c_sharp = @import("languages/c_sharp.zig");
    pub const diff = @import("languages/diff.zig");
    pub const dockerfile = @import("languages/dockerfile.zig");
    pub const hcl = @import("languages/hcl.zig");
    pub const go = @import("languages/go.zig");
    pub const json = @import("languages/json.zig");
    pub const javascript = @import("languages/javascript.zig");
    pub const jsdoc = @import("languages/jsdoc.zig");
    pub const java = @import("languages/java.zig");
    pub const kotlin = @import("languages/kotlin.zig");
    pub const lua = @import("languages/lua.zig");
    pub const make = @import("languages/make.zig");
    pub const nasm = @import("languages/nasm.zig");
    pub const objc = @import("languages/objc.zig");
    pub const php = @import("languages/php.zig");
    pub const powershell = @import("languages/powershell.zig");
    pub const proto = @import("languages/proto.zig");
    pub const python = @import("languages/python.zig");
    pub const regex = @import("languages/regex.zig");
    pub const rust = @import("languages/rust.zig");
    pub const ruby = @import("languages/ruby.zig");
    pub const sql = @import("languages/sql.zig");
    pub const toml = @import("languages/toml.zig");
    pub const swift = @import("languages/swift.zig");
    pub const typescript = @import("languages/typescript.zig");
    pub const vue = @import("languages/vue.zig");
    pub const yaml = @import("languages/yaml.zig");
    pub const zig = @import("languages/zig.zig");
};

test "span preserves source offsets" {
    const source = "const answer = 42;";
    const span: Span = try .init(0, 5);

    try std.testing.expectEqualStrings("const", try span.slice(source));
}
