//! Source-preserving primitives for native syntax highlighting.

const std = @import("std");

const capture = @import("capture.zig");
const backend = @import("backend.zig");

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

test "span preserves source offsets" {
    const source = "const answer = 42;";
    const span: Span = try .init(0, 5);

    try std.testing.expectEqualStrings("const", try span.slice(source));
}
