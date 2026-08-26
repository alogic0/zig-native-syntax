const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.hcl.backend;

test "HCL backend metadata is stable" {
    try std.testing.expectEqualStrings("hcl", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
}

test "HCL scanner distinguishes properties traversals calls and templates" {
    const source = "enabled = true\nname = format(\"app-${var.env}\")\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "enabled", .property);
    try expectCapture(source, sink.captures(), "true", .boolean);
    try expectCapture(source, sink.captures(), "format", .function);
    try expectCapture(source, sink.captures(), "${", .embedded);
    try expectCapture(source, sink.captures(), "\"app-${var.env}\"", .string);
}

test "HCL representative infrastructure corpora retain lexical roles" {
    for ([_][]const u8{
        @embedFile("corpus/hcl/complete.hcl"),
        @embedFile("corpus/hcl/module.hcl"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);
        try std.testing.expect(hasScope(sink.captures(), .keyword));
        try std.testing.expect(hasScope(sink.captures(), .property));
        try std.testing.expect(hasScope(sink.captures(), .string));
    }
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| if (capture.scope == expected) return true;
    return false;
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
