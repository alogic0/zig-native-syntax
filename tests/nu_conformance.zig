const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "Nushell backend conforms" {
    try conformance.expectConforms(syntax.languages.nu.backend, .{
        .valid = .{ .source = @embedFile("corpus/nu/pipeline.nu"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .function, .builtin, .parameter, .attribute, .variable, .type, .property, .namespace } },
        .malformed = .{ .source = "def broken [value: list<string> { let text = \"unterminated\nlet recovered = true\n", .required_scopes = &.{ .keyword, .function, .parameter, .type, .string, .variable, .boolean } },
        .multiline = .{ .source = "open first.nu\nopen second.nu | lines\n", .required_scopes = &.{ .function, .builtin } },
        .escapable = .{ .source = "let value = \"<&>\\q'\" # comment", .required_scopes = &.{ .keyword, .variable, .string, .escape, .comment } },
    });
}

test "Nushell parser classifies pipelines signatures and closures" {
    const source = @embedFile("corpus/nu/pipeline.nu");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.nu.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "main", .function);
    try expect(source, sink.captures(), "input", .parameter);
    try expect(source, sink.captures(), "--format", .attribute);
    try expect(source, sink.captures(), "-f", .attribute);
    try expect(source, sink.captures(), "record", .type);
    try expect(source, sink.captures(), "files", .variable);
    try expect(source, sink.captures(), "glob", .builtin);
    try expect(source, sink.captures(), "$files", .variable);
    try expect(source, sink.captures(), "file", .parameter);
    try expect(source, sink.captures(), "path", .property);
    try expect(source, sink.captures(), "each", .builtin);
    try expect(source, sink.captures(), "str", .builtin);
    try expect(source, sink.captures(), "trim", .function);
    try expect(source, sink.captures(), "helpers", .namespace);
    try expect(source, sink.captures(), "^git", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
