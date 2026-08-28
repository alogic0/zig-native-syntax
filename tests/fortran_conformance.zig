const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.fortran.backend;

test "Fortran backend is verified and case insensitive" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    const source = "MODULE Demo\nINTEGER :: Count\nCALL Run(Count)\nEND MODULE Demo";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "MODULE", .keyword);
    try expect(source, sink.captures(), "INTEGER", .type);
    try expect(source, sink.captures(), "Run", .function);
}

test "Fortran backend classifies structural declarations and references" {
    const source =
        \\module Geometry
        \\  use, intrinsic :: iso_fortran_env
        \\  type, extends(shape) :: Circle
        \\    real :: radius
        \\  contains
        \\    procedure :: area => circle_area
        \\  end type Circle
        \\contains
        \\  pure function circle_area(self, scale) result(total)
        \\    type(Circle), intent(in) :: self
        \\    real, intent(in) :: scale
        \\    total = self%radius * scale
        \\    call report(total)
        \\  end function circle_area
        \\end module Geometry
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "Geometry", .namespace);
    try expect(source, sink.captures(), "iso_fortran_env", .namespace);
    try expect(source, sink.captures(), "shape", .type);
    try expect(source, sink.captures(), "Circle", .type);
    try expect(source, sink.captures(), "radius", .property);
    try expect(source, sink.captures(), "area", .property);
    try expect(source, sink.captures(), "circle_area", .function);
    try expect(source, sink.captures(), "self", .parameter);
    try expect(source, sink.captures(), "scale", .parameter);
    try expect(source, sink.captures(), "total", .variable);
    try expect(source, sink.captures(), "report", .function);
}

test "Fortran backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/fortran/complete.f90"), .required_scopes = &.{ .keyword, .type, .function, .namespace, .parameter, .property, .variable, .comment, .operator, .punctuation } },
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

test "Fortran single pass separates declarations from initializers" {
    const source =
        \\real :: value = transform(input)
        \\logical :: ok = .true.
        \\integer :: mask = Z'FF'
        \\module trailing_name
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "value", .variable);
    try expect(source, sink.captures(), "transform", .function);
    try expect(source, sink.captures(), "input", .variable);
    try expect(source, sink.captures(), ".true.", .boolean);
    try expect(source, sink.captures(), "Z'FF'", .number);
    try expect(source, sink.captures(), "trailing_name", .namespace);
    try expectNot(source, sink.captures(), "true", .variable);
    try expectNot(source, sink.captures(), "Z", .variable);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectNot(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return error.TestUnexpectedResult;
    }
}
