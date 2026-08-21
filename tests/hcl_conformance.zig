const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.hcl.backend;

test "HCL backend metadata is stable" {
    try std.testing.expectEqualStrings("hcl", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "HCL scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'k', 'e', 'y', ' ', '=', ' ', '"', 0xff, '"' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/hcl/complete.hcl"),
            .required_scopes = &.{ .keyword, .property, .type, .boolean, .constant, .number, .string, .escape, .embedded, .variable, .function, .operator, .punctuation, .comment, .label },
        },
        .malformed = .{
            .source = "root {\n  value = \"unterminated\\u12<&>\n  next = true\n}\n",
            .required_scopes = &.{ .variable, .property, .string, .escape, .boolean, .operator, .punctuation },
        },
        .multiline = .{
            .source = "text = <<-EOF\n  first <&>\n  second ${value}\nEOF\nnext = false\n",
            .required_scopes = &.{ .property, .operator, .label, .string, .boolean },
        },
        .escapable = .{
            .source = "value = \"<&>\\\"' ${name}\" # comment",
            .required_scopes = &.{ .property, .string, .escape, .embedded, .comment },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .property, .string, .operator },
        },
        .extra_cases = &.{.{
            .source = "/* incomplete <&>\n",
            .required_scopes = &.{.comment},
        }},
    });
}
