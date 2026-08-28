const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.latex.backend;

test "LaTeX metadata and focused roles are stable" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "\\begin{document}\\section*{Title} $x_1^2$ \\% \\end{document}";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "\\begin", .keyword);
    try expectCapture(source, sink.captures(), "document", .tag);
    try expectCapture(source, sink.captures(), "$x_1^2$", .markup_code);
    try expectCapture(source, sink.captures(), "\\%", .escape);
}

test "LaTeX backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/latex/complete.txt"), .required_scopes = &.{ .keyword, .tag, .markup_code, .comment, .punctuation } },
        .malformed = .{ .source = "\\begin{document\n$unterminated <&>\n", .required_scopes = &.{ .keyword, .markup_code } },
        .multiline = .{ .source = "\\section{First}\nText % note\n", .required_scopes = &.{ .keyword, .comment } },
        .escapable = .{ .source = "\\texttt{<&>\"'} \\% % comment", .required_scopes = &.{ .keyword, .escape, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/latex/article.tex"), .required_scopes = &.{ .keyword, .tag, .markup_code, .comment } }},
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
