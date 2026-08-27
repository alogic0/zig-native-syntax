const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.query.backend;

test "Tree-sitter Query metadata and structural roles are stable" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "(function_definition name: (identifier) @function (#match? @function \"^render\\d+$\"))";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "function_definition", .type);
    try expectCapture(source, sink.captures(), "name", .property);
    try expectCapture(source, sink.captures(), "@function", .attribute);
    try expectCapture(source, sink.captures(), "#match?", .function);
    try expectCapture(source, sink.captures(), "\\d", .escape);
}

test "Tree-sitter Query backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/query/complete.txt"), .required_scopes = &.{ .type, .property, .attribute, .function, .constant, .string, .escape, .comment, .operator, .punctuation } },
        .malformed = .{ .source = "(call function: (identifier) @call (#match? @call \"unterminated\\n<&>", .required_scopes = &.{ .type, .property, .attribute, .function, .string, .escape } },
        .multiline = .{ .source = "(identifier) @name\n(ERROR) @error\n", .required_scopes = &.{ .type, .attribute, .constant } },
        .escapable = .{ .source = "(string \"<&>\\\"'\") @value ; comment", .required_scopes = &.{ .type, .string, .escape, .attribute, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/query/highlights.scm"), .required_scopes = &.{ .type, .property, .attribute, .function, .string } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
