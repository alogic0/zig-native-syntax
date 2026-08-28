const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.gitcommit.backend;

test "Git commit scanner is verified and conforms" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/gitcommit/complete.txt"), .required_scopes = &.{ .markup_heading, .keyword, .punctuation, .comment } },
        .malformed = .{ .source = "feat(scope unfinished\n# <&> note", .required_scopes = &.{ .markup_heading, .keyword, .comment } },
        .multiline = .{ .source = "fix(ui)!: render\n\nbody <&>\n# note\n", .required_scopes = &.{ .markup_heading, .keyword, .label, .operator, .comment } },
        .escapable = .{ .source = "docs: keep <&>\n# \"quoted\" ' note", .required_scopes = &.{ .markup_heading, .keyword, .comment } },
    });
}

test "Git commit assigns conventional and status roles exactly" {
    const source = "feat(viewer)!: add themes\n\n# Changes to be committed:\n#\tmodified: src/main.zig";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "feat", .keyword);
    try expect(source, sink.captures(), "viewer", .label);
    try expect(source, sink.captures(), "!", .operator);
    try expect(source, sink.captures(), "feat(viewer)!: add themes", .markup_heading);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
