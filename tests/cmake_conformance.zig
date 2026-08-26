const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "CMake backend conforms" {
    const backend = syntax.languages.cmake.backend;
    try std.testing.expectEqualStrings("cmake", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/cmake/complete.cmake"), .required_scopes = &.{ .keyword, .function, .variable, .string, .escape, .boolean, .comment, .punctuation } },
        .malformed = .{ .source = "set(NAME \"unterminated\\q<&>\nif(ON)\n", .required_scopes = &.{ .function, .string, .escape, .keyword, .boolean } },
        .multiline = .{ .source = "function(build name)\n message(STATUS \"<&>\")\nendfunction()\n", .required_scopes = &.{ .keyword, .function, .string } },
        .escapable = .{ .source = "set(X \"<&>\\\"'\") # comment", .required_scopes = &.{ .function, .string, .escape, .comment } },
    });
}

test "CMake scanner distinguishes commands control flow variables and values" {
    const backend = syntax.languages.cmake.backend;
    const source = "set(NAME \"demo\")\nif(ON)\n  message(STATUS ${NAME})\nendif()";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "set", .function);
    try expectCapture(source, sink.captures(), "if", .keyword);
    try expectCapture(source, sink.captures(), "ON", .boolean);
    try expectCapture(source, sink.captures(), "message", .function);
    try expectCapture(source, sink.captures(), "${NAME}", .variable);
    try expectCapture(source, sink.captures(), "endif", .keyword);
}

test "CMake representative project corpora retain lexical roles" {
    const backend = syntax.languages.cmake.backend;
    for ([_][]const u8{
        @embedFile("corpus/cmake/complete.cmake"),
        @embedFile("corpus/cmake/library.cmake"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);
        try std.testing.expect(hasScope(sink.captures(), .function));
        try std.testing.expect(hasScope(sink.captures(), .keyword));
        try std.testing.expect(hasScope(sink.captures(), .string));
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
