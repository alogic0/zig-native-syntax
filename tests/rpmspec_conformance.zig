const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.rpmspec.backend;

test "RPM spec metadata and composed roles are stable" {
    try std.testing.expectEqual(syntax.BackendKind.composed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "Name: viewer\nVersion: 1.2\nSource0: %{name}.tar.gz\n%build\nfor file in *.md; do echo \"$file\"; done\n%files\n%doc README.md\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "Name:", .property);
    try expectCapture(source, sink.captures(), "%{name}", .macro);
    try expectCapture(source, sink.captures(), "%build", .keyword);
    try expectCapture(source, sink.captures(), "for", .keyword);
    try expectCapture(source, sink.captures(), "$file", .variable);
    try expectCapture(source, sink.captures(), "%doc", .macro);
}

test "RPM spec backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/rpmspec/complete.txt"), .required_scopes = &.{ .property, .number, .macro, .keyword, .variable, .string, .comment, .markup_list } },
        .malformed = .{ .source = "Name: viewer\nSource: %{unterminated\n%build\necho \"unterminated\\n<&>\n", .required_scopes = &.{ .property, .macro, .keyword, .string, .escape } },
        .multiline = .{ .source = "%install\nmkdir -p %{buildroot}/usr/bin\ncp viewer %{buildroot}/usr/bin\n", .required_scopes = &.{ .keyword, .macro } },
        .escapable = .{ .source = "%build\necho \"<&>\\q'\" # comment", .required_scopes = &.{ .keyword, .string, .escape, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/rpmspec/viewer.spec"), .required_scopes = &.{ .property, .macro, .keyword, .variable, .string, .markup_list } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
