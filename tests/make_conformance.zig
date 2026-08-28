const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "Make backend conforms to the shared contract" {
    const backend = syntax.languages.make.backend;
    try std.testing.expectEqualStrings("make", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const invalid = [_]u8{ 'X', ' ', '=', ' ', 0xff };
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/make/complete.mk"), .required_scopes = &.{ .keyword, .property, .label, .variable, .string, .escape, .operator, .comment, .embedded } },
        .malformed = .{ .source = "VALUE = \"unterminated\\q<&>\nnext: dep\n", .required_scopes = &.{ .property, .string, .escape, .label, .operator } },
        .multiline = .{ .source = "target: dep\n\t@echo '<&>' $(VALUE)\n", .required_scopes = &.{ .label, .operator, .embedded } },
        .escapable = .{ .source = "VALUE = \"<&>\\\"'\" # comment", .required_scopes = &.{ .property, .string, .escape, .comment } },
        .invalid_utf8 = .{ .source = &invalid, .required_scopes = &.{ .property, .operator } },
    });
}

test "Make composes assignment target variable and shell recipe roles" {
    const backend = syntax.languages.make.backend;
    const source = "CC := cc\napp: main.c\n\t@echo \"$(CC)\"\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "CC", .property);
    try expectCapture(source, sink.captures(), "app", .label);
    try expectCapture(source, sink.captures(), "echo", .builtin);
    try expectCapture(source, sink.captures(), "echo", .function);
    try expectCapture(source, sink.captures(), "$(CC)", .variable);
    try expectCapture(source, sink.captures(), "@", .special);
    try expectCapture(source, sink.captures(), "echo \"$(CC)\"", .embedded);
}

test "Make representative build corpora retain composed roles" {
    const backend = syntax.languages.make.backend;
    for ([_][]const u8{
        @embedFile("corpus/make/complete.mk"),
        @embedFile("corpus/make/library.mk"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);
        try std.testing.expect(hasScope(sink.captures(), .property));
        try std.testing.expect(hasScope(sink.captures(), .label));
        try std.testing.expect(hasScope(sink.captures(), .embedded));
        try std.testing.expect(hasScope(sink.captures(), .function));
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
