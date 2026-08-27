const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.fortran.backend;

test "Fortran backend is verified and case insensitive" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    const source = "MODULE Demo\nINTEGER :: Count\nCALL Run(Count)\nEND MODULE Demo";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "MODULE", .keyword);
    try expect(source, sink.captures(), "INTEGER", .type);
    try expect(source, sink.captures(), "Run", .function);
}

test "Fortran backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/fortran/complete.f90"), .required_scopes = &.{ .keyword, .type, .function, .variable, .comment, .operator, .punctuation } },
        .malformed = .{ .source = "program open\ncharacter(*) :: value = \"unterminated<&>\nend", .required_scopes = &.{ .keyword, .type, .variable, .string } },
        .multiline = .{ .source = "integer :: first\nreal :: second\n", .required_scopes = &.{ .type, .variable } },
        .escapable = .{ .source = "character(*) :: s = \"<&>\\\"'\" ! comment", .required_scopes = &.{ .type, .string, .escape, .comment } },
    });
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
