const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "AWK backend conforms" {
    try conformance.expectConforms(syntax.languages.awk.backend, .{
        .valid = .{ .source = @embedFile("corpus/awk/report.awk"), .required_scopes = &.{ .keyword, .string, .escape, .number, .comment, .function, .builtin, .parameter, .variable, .operator, .attribute } },
        .malformed = .{ .source = "function broken(value, fallback { print \"unterminated\nnext /unterminated\n", .required_scopes = &.{ .keyword, .function, .parameter, .builtin, .string } },
        .multiline = .{ .source = "BEGIN { print first }\n$1 ~ /value/ { print second }\n", .required_scopes = &.{ .keyword, .builtin, .variable, .string } },
        .escapable = .{ .source = "BEGIN { value = \"<&>\\q'\" } # comment", .required_scopes = &.{ .keyword, .variable, .string, .escape, .comment } },
    });
}

test "AWK parser distinguishes regex division functions and fields" {
    const source = @embedFile("corpus/awk/report.awk");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.awk.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "@include", .attribute);
    try expect(source, sink.captures(), "FS", .builtin);
    try expect(source, sink.captures(), "$3", .variable);
    try expect(source, sink.captures(), "/^[[:digit:]]+(\\.[[:digit:]]+)?$/", .string);
    try expect(source, sink.captures(), "/", .operator);
    try expect(source, sink.captures(), "normalize", .function);
    try expect(source, sink.captures(), "value", .parameter);
    try expect(source, sink.captures(), "fallback", .parameter);
    try expect(source, sink.captures(), "sprintf", .builtin);
    try expect(source, sink.captures(), "totals", .variable);
    try expect(source, sink.captures(), "printf", .builtin);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
