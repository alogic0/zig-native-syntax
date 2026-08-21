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
    pub const bash = @import("languages/bash.zig");
    pub const c = @import("languages/c.zig");
    pub const diff = @import("languages/diff.zig");
    pub const dockerfile = @import("languages/dockerfile.zig");
    pub const hcl = @import("languages/hcl.zig");
    pub const json = @import("languages/json.zig");
    pub const javascript = @import("languages/javascript.zig");
    pub const python = @import("languages/python.zig");
    pub const rust = @import("languages/rust.zig");
    pub const sql = @import("languages/sql.zig");
    pub const toml = @import("languages/toml.zig");
    pub const typescript = @import("languages/typescript.zig");
    pub const yaml = @import("languages/yaml.zig");
    pub const zig = @import("languages/zig.zig");
};

test "span preserves source offsets" {
    const source = "const answer = 42;";
    const span: Span = try .init(0, 5);

    try std.testing.expectEqualStrings("const", try span.slice(source));
}
