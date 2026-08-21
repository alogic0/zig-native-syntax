const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "Make backend conforms to the shared contract" {
    const backend = syntax.languages.make.backend;
    try std.testing.expectEqualStrings("make", backend.info.canonical_name);
    const invalid = [_]u8{ 'X', ' ', '=', ' ', 0xff };
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/make/complete.mk"), .required_scopes = &.{ .keyword, .property, .label, .variable, .string, .escape, .operator, .comment, .embedded } },
        .malformed = .{ .source = "VALUE = \"unterminated\\q<&>\nnext: dep\n", .required_scopes = &.{ .property, .string, .escape, .label, .operator } },
        .multiline = .{ .source = "target: dep\n\t@echo '<&>' $(VALUE)\n", .required_scopes = &.{ .label, .operator, .embedded } },
        .escapable = .{ .source = "VALUE = \"<&>\\\"'\" # comment", .required_scopes = &.{ .property, .string, .escape, .comment } },
        .invalid_utf8 = .{ .source = &invalid, .required_scopes = &.{ .property, .operator } },
    });
}
