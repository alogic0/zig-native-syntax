const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.ninja.backend;

test "Ninja scanner is verified and conforms" {
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/ninja/complete.txt"), .required_scopes = &.{ .keyword, .property, .label, .type, .string, .variable, .operator, .comment } },
        .malformed = .{ .source = "rule cc\n  command = \"unterminated\\q<&>\nbuild out.o: cc in.c", .required_scopes = &.{ .keyword, .label, .property, .string, .escape, .operator, .type } },
        .multiline = .{ .source = "command = cc $in $\n  -o $out\n", .required_scopes = &.{ .property, .operator, .variable } },
        .escapable = .{ .source = "command = echo \"<&>\\\"'\" $in # note", .required_scopes = &.{ .property, .string, .escape, .variable, .comment } },
    });
}

test "Ninja assigns rule build binding and variable roles exactly" {
    const source = "rule cc\n  command = cc $in -o $out\nbuild app: cc main.c";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "rule", .keyword);
    try expect(source, sink.captures(), "cc", .label);
    try expect(source, sink.captures(), "command", .property);
    try expect(source, sink.captures(), "$in", .variable);
    try expect(source, sink.captures(), "app", .label);
    try expect(source, sink.captures(), "cc", .type);
    try expect(source, sink.captures(), "main.c", .string);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
