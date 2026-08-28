const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.elixir.backend;

test "Elixir backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/elixir/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .attribute, .namespace, .type, .function, .parameter, .property, .constant, .special } },
        .malformed = .{ .source = "defmodule Broken do\n  def run(input, opts \\\\ [ do\n    value = ~r/(open/\n    text = \"unterminated\n  end\nend\n", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .string, .special } },
        .multiline = .{ .source = "defmodule First do\nend\ndefmodule Second do\nend\n", .required_scopes = &.{ .keyword, .namespace } },
        .escapable = .{ .source = "def run(value), do: \"<&>\\q'\" # comment", .required_scopes = &.{ .keyword, .function, .parameter, .property, .string, .escape, .comment } },
    });
}

test "Elixir parser classifies modules declarations and sigils" {
    const source = @embedFile("corpus/elixir/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "Demo.Worker", .namespace);
    try expect(source, sink.captures(), "@spec", .attribute);
    try expect(source, sink.captures(), "run", .function);
    try expect(source, sink.captures(), "input", .parameter);
    try expect(source, sink.captures(), "opts", .parameter);
    try expect(source, sink.captures(), "~r/^[a-z]+$/u", .string);
    try expect(source, sink.captures(), "~r", .special);
    try expect(source, sink.captures(), "~S\"\"\"\n    literal #{input} and \\\\n\n    \"\"\"", .string);
    try expect(source, sink.captures(), "~S", .special);
    try expect(source, sink.captures(), ":ok", .constant);
    try expect(source, sink.captures(), "Keyword", .type);
    try expect(source, sink.captures(), "fetch", .function);
    try expect(source, sink.captures(), "limit", .property);
    try expect(source, sink.captures(), "parse", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
