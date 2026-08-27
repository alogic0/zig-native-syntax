const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.c.backend;

test "C backend metadata is stable" {
    try std.testing.expectEqualStrings("c", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
}

test "C declaration parser distinguishes contextual roles" {
    const source = "typedef struct Entry { int value; } Entry; static int render(const Entry *entry) { retry: return helper(entry->value); }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "Entry", .type);
    try expectCapture(source, sink.captures(), "render", .function);
    try expectCapture(source, sink.captures(), "entry", .parameter);
    try expectCapture(source, sink.captures(), "retry", .label);
    try expectCapture(source, sink.captures(), "helper", .function);
    try expectCapture(source, sink.captures(), "value", .property);
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

test "C scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'i', 'n', 't', ' ', 0xff, ';' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/c/complete.c"),
            .required_scopes = &.{ .macro, .comment, .documentation, .keyword, .builtin, .type, .function, .variable, .string, .escape, .constant, .number, .operator, .punctuation },
        },
        .malformed = .{
            .source = "#define OPEN(x) \\\n  ((x) + 1\nint main( { return \"unterminated\\n<&>",
            .required_scopes = &.{ .macro, .builtin, .function, .keyword, .string, .escape },
        },
        .multiline = .{
            .source = "/* open\n comment <&> */\nint done(void) { return 0; }\n",
            .required_scopes = &.{ .comment, .builtin, .function, .keyword, .number },
        },
        .escapable = .{
            .source = "const char *s = \"<&>\\\"'\";",
            .required_scopes = &.{ .keyword, .builtin, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .builtin, .punctuation },
        },
    });
}
