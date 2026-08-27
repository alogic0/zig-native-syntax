const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.org.backend;

test "Org metadata and focused roles are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "* TODO Render [[file:doc.md][document]]\n:OWNER: viewer\n#+BEGIN_SRC zig\nconst x = 1;\n#+END_SRC\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "TODO", .keyword);
    try expectCapture(source, sink.captures(), "[[file:doc.md][document]]", .markup_link);
    try expectCapture(source, sink.captures(), ":OWNER:", .property);
    try expectCapture(source, sink.captures(), "zig", .tag);
    try expectCapture(source, sink.captures(), "const x = 1;", .embedded);
}

test "Org Mode backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/org/complete.txt"), .required_scopes = &.{ .markup_heading, .keyword, .attribute, .tag, .embedded, .markup_link, .comment } },
        .malformed = .{ .source = "* TODO <&>\n[[unterminated\n#+BEGIN_SRC bash\necho hi\n", .required_scopes = &.{ .markup_heading, .markup_link, .attribute, .tag, .embedded } },
        .multiline = .{ .source = "* First\n** DONE Second\n", .required_scopes = &.{ .markup_heading, .keyword } },
        .escapable = .{ .source = "* <&>\"' [[https://example.test][link]]\n# comment", .required_scopes = &.{ .markup_heading, .markup_link, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/org/project.org"), .required_scopes = &.{ .markup_heading, .property, .markup_list, .attribute, .embedded } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
