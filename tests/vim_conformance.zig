const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.vim.backend;

test "Vimscript backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/vim/complete.txt"),
            .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .variable, .macro, .string, .number, .boolean, .comment },
        },
        .malformed = .{
            .source = "let value = 'unterminated\\q<&>\nlet enabled = v:true\n",
            .required_scopes = &.{ .keyword, .variable, .string, .escape, .operator, .boolean },
        },
        .multiline = .{
            .source = "let first = 1\nlet second = 2\n",
            .required_scopes = &.{ .keyword, .variable, .number },
        },
        .escapable = .{
            .source = "let value = '<&>\\q\"' \" comment",
            .required_scopes = &.{ .keyword, .string, .escape, .comment },
        },
    });
}

test "Vimscript parser classifies legacy and Vim9 declarations and expressions" {
    const source = @embedFile("corpus/vim/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "util", .namespace);
    try expect(source, sink.captures(), "Render", .function);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "message", .variable);
    try expect(source, sink.captures(), "Format", .function);
    try expect(source, sink.captures(), "s:Legacy", .function);
    try expect(source, sink.captures(), "value", .parameter);
    try expect(source, sink.captures(), "l:item", .variable);
    try expect(source, sink.captures(), "a:value", .variable);
    try expect(source, sink.captures(), "s:Render", .function);
    try expect(source, sink.captures(), "Show", .macro);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
