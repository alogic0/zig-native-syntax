const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "RPM Bash backend conforms" {
    try conformance.expectConforms(syntax.languages.rpmbash.backend, .{
        .valid = .{ .source = @embedFile("corpus/rpmbash/complete.txt"), .required_scopes = &.{ .keyword, .variable, .string, .escape, .number, .comment } },
        .malformed = .{ .source = "echo \"unterminated\\q<&>\n", .required_scopes = &.{ .string, .escape } },
        .multiline = .{ .source = "if true; then\n echo '<&>'\nfi\n", .required_scopes = &.{ .keyword, .string } },
        .escapable = .{ .source = "echo \"<&>\\q'\" # comment", .required_scopes = &.{ .string, .escape, .comment } },
    });
}
