const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.haskell.backend;

test "Haskell backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/haskell/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .attribute, .namespace, .type, .constructor, .function, .parameter, .property } },
        .malformed = .{ .source = "module Broken where\n{- outer {- nested\nrun value = \"unterminated\n", .required_scopes = &.{ .keyword, .namespace, .comment } },
        .multiline = .{ .source = "module First where\nfirst = 1\nmodule Second where\nsecond = 2\n", .required_scopes = &.{ .keyword, .namespace, .function, .number } },
        .escapable = .{ .source = "run value = \"<&>\\q'\" -- comment", .required_scopes = &.{ .function, .parameter, .string, .escape, .comment } },
    });
}

test "Haskell parser classifies declarations signatures and constructors" {
    const source = @embedFile("corpus/haskell/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "{-# LANGUAGE DeriveGeneric #-}", .attribute);
    try expect(source, sink.captures(), "Demo.Shapes", .namespace);
    try expect(source, sink.captures(), "Data.Map.Strict", .namespace);
    try expect(source, sink.captures(), "Shape", .type);
    try expect(source, sink.captures(), "Circle", .constructor);
    try expect(source, sink.captures(), "radius", .property);
    try expect(source, sink.captures(), "area", .function);
    try expect(source, sink.captures(), "shape", .parameter);
    try expect(source, sink.captures(), "Double", .type);
    try expect(source, sink.captures(), "total", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
