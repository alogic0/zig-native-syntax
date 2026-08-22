const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.typescript.backend;

test "TypeScript backend metadata is stable" {
    try std.testing.expectEqualStrings("typescript", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
}

test "TypeScript parser conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 't', 'y', 'p', 'e', ' ', 0xff, '=', 's', 't', 'r', 'i', 'n', 'g' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/typescript/complete.ts"),
            .required_scopes = &.{ .comment, .documentation, .keyword, .type, .builtin, .function, .property, .variable, .string, .escape, .boolean, .constant, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "interface Broken<T extends { value: string\nconst text = `unfinished ${value}\\n<&>",
            .required_scopes = &.{ .keyword, .type, .builtin, .variable, .string, .escape, .punctuation },
        },
        .multiline = .{
            .source = "/** docs\n * <&>\n */\ntype Name = string;\n",
            .required_scopes = &.{ .comment, .documentation, .keyword, .type, .builtin },
        },
        .escapable = .{
            .source = "const value: string = \"<&>\\\"'\";",
            .required_scopes = &.{ .keyword, .variable, .builtin, .type, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .builtin, .type, .operator },
        },
    });
}

test "TypeScript parser classifies declaration names and references as types" {
    const source = "interface User {} const current: User = load();";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    const declaration = std.mem.indexOf(u8, source, "User") orelse unreachable;
    const reference = std.mem.lastIndexOf(u8, source, "User") orelse unreachable;
    try expectScopeAt(sink.captures(), declaration, declaration + 4, .type);
    try expectScopeAt(sink.captures(), reference, reference + 4, .type);
}

fn expectScopeAt(
    captures: []const syntax.Capture,
    start: usize,
    end: usize,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.span.start == start and capture.span.end == end and capture.scope == scope) return;
    }
    return error.TestExpectedEqual;
}
