const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "CMake backend conforms" {
    const backend = syntax.languages.cmake.backend;
    try std.testing.expectEqualStrings("cmake", backend.info.canonical_name);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/cmake/complete.cmake"), .required_scopes = &.{ .keyword, .function, .variable, .string, .escape, .boolean, .comment, .punctuation } },
        .malformed = .{ .source = "set(NAME \"unterminated\\q<&>\nif(ON)\n", .required_scopes = &.{ .function, .string, .escape, .keyword, .boolean } },
        .multiline = .{ .source = "function(build name)\n message(STATUS \"<&>\")\nendfunction()\n", .required_scopes = &.{ .keyword, .function, .string } },
        .escapable = .{ .source = "set(X \"<&>\\\"'\") # comment", .required_scopes = &.{ .function, .string, .escape, .comment } },
    });
}
