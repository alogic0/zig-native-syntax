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
        .malformed = .{ .source = "program demo\ncharacter(*) :: item = \"unterminated<&>\nend", .required_scopes = &.{ .keyword, .type, .variable, .string } },
        .multiline = .{ .source = "integer :: first\nreal :: second\n", .required_scopes = &.{ .type, .variable } },
        .escapable = .{ .source = "character(*) :: s = '<&> \\ \" don''t' ! comment", .required_scopes = &.{ .type, .string, .escape, .comment } },
    });
}

test "Fortran scanner respects free and fixed form lexical rules" {
    const source =
        \\C fixed form comment
        \\  100 CONTINUE
        \\     1 VALUE = Z'2A' + 1.25_real64
        \\name = 'don''t' // "stop!"
        \\if (.TRUE. .and. name /= '') name = name &
        \\  & // 'next'
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "C fixed form comment", .comment);
    try expect(source, sink.captures(), "100", .label);
    try expect(source, sink.captures(), "1", .punctuation);
    try expect(source, sink.captures(), "Z'2A'", .number);
    try expect(source, sink.captures(), "1.25_real64", .number);
    try expect(source, sink.captures(), "''", .escape);
    try expect(source, sink.captures(), ".TRUE.", .boolean);
    try expect(source, sink.captures(), ".and.", .operator);
    try expect(source, sink.captures(), "/=", .operator);
    try expect(source, sink.captures(), "&", .punctuation);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
