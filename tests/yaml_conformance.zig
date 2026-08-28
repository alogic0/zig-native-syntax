const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.yaml.backend;

test "YAML backend metadata is stable" {
    try std.testing.expectEqualStrings("yaml", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
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

test "YAML distinguishes mapping keys and primitive values" {
    const source =
        \\123: 456
        \\true: false
        \\missing: ~
        \\defaults: &defaults
        \\merge:
        \\  <<: *defaults
        \\text: |
        \\  first
        \\  second
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "123", .property);
    try expectCapture(source, sink.captures(), "456", .number);
    try expectCapture(source, sink.captures(), "true", .property);
    try expectCapture(source, sink.captures(), "false", .boolean);
    try expectCapture(source, sink.captures(), "~", .constant);
    try expectCapture(source, sink.captures(), "&defaults", .label);
    try expectCapture(source, sink.captures(), "<<", .property);
    try expectCapture(source, sink.captures(), "*defaults", .variable);
    try expectCapture(source, sink.captures(), "first", .string);
}

test "YAML representative configuration corpora retain lexical roles" {
    for ([_][]const u8{
        @embedFile("corpus/yaml/kubernetes.yaml"),
        @embedFile("corpus/yaml/workflow.yaml"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);

        try expectCapture(source, sink.captures(), "name", .property);
        try std.testing.expect(hasScope(sink.captures(), .string));
        try std.testing.expect(hasScope(sink.captures(), .punctuation));
    }
}

fn expectCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| if (capture.scope == expected) return true;
    return false;
}
