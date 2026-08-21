const syntax = @import("native_syntax");
const conformance = @import("backend_conformance.zig");
pub fn expect(backend: syntax.Backend, complete: []const u8, required: []const syntax.Scope, escapable: []const u8) !void {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = complete, .required_scopes = required },
        .malformed = .{ .source = "value = \"unterminated\\u12<&>\nnext = true\n", .required_scopes = &.{ .string, .escape, .operator, .boolean } },
        .multiline = .{ .source = "first\nsecond\n", .required_scopes = &.{.variable} },
        .escapable = .{ .source = escapable, .required_scopes = &.{ .string, .escape, .comment } },
    });
}
