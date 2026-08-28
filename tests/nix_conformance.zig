const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "Nix backend conforms" {
    try conformance.expectConforms(syntax.languages.nix.backend, .{
        .valid = .{ .source = @embedFile("corpus/nix/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .variable, .property, .parameter, .builtin, .embedded, .special } },
        .malformed = .{ .source = "value = \"unterminated\\u12<&>\nnext = true\n", .required_scopes = &.{ .property, .string, .escape } },
        .multiline = .{ .source = "first\nsecond\n", .required_scopes = &.{.variable} },
        .escapable = .{ .source = "value = \"<&>\\q'\" # comment", .required_scopes = &.{ .property, .string, .escape, .comment } },
    });
}

test "Nix parser distinguishes bindings parameters attributes and interpolation" {
    const source = "let local = { name, count ? 1 }: { service.name = \"${builtins.toString count}\"; inherit name; }; in local";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.nix.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "local", .variable);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "count", .parameter);
    try expect(source, sink.captures(), "service", .property);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "builtins", .builtin);
    try expect(source, sink.captures(), "toString", .property);
    try expect(source, sink.captures(), "${", .special);
}

test "Nix parser covers flakes modules paths and indented escapes" {
    const source = @embedFile("corpus/nix/flake.nix");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.nix.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "system", .variable);
    try expect(source, sink.captures(), "packages", .property);
    try expect(source, sink.captures(), "${system}", .property);
    try expect(source, sink.captures(), "./package.nix", .string);
    try expect(source, sink.captures(), "${dynamicName}", .property);
    try expect(source, sink.captures(), "inputs", .variable);
    try expect(source, sink.captures(), "nixpkgs", .property);
    try expect(source, sink.captures(), "<nixpkgs>", .string);
    try expect(source, sink.captures(), "https://example.org/viewer", .string);
    try expectMissing(source, sink.captures(), "notInterpolation", .variable);
    try expectMissing(source, sink.captures(), "notInterpolation", .embedded);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectMissing(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return error.TestUnexpectedResult;
    }
}
