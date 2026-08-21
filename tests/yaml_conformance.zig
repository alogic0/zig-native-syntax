const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.yaml.backend;

test "YAML backend metadata is stable" {
    try std.testing.expectEqualStrings("yaml", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "YAML scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'k', 'e', 'y', ':', ' ', '"', 0xff, '"' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/yaml/complete.yaml"),
            .required_scopes = &.{ .special, .property, .label, .variable, .type, .string, .escape, .boolean, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "root:\n  value: \"unterminated\\u12<&>\nnext: true\n",
            .required_scopes = &.{ .property, .string, .escape, .boolean, .operator },
        },
        .multiline = .{
            .source = "text: |\n  first <&>\n  second\nnext: false\n",
            .required_scopes = &.{ .property, .operator, .string, .boolean },
        },
        .escapable = .{
            .source = "html: \"<&>\\\"'\" # comment",
            .required_scopes = &.{ .property, .string, .escape, .comment },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .property, .string, .operator },
        },
    });
}
