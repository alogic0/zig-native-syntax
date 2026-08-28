const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.perl.backend;

test "Perl backend conforms" {
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/perl/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .documentation, .namespace, .type, .function, .parameter, .variable, .property, .builtin, .special, .label } },
        .malformed = .{ .source = "package Broken;\nsub run ($value {\n my $doc = <<'END'\nbody\nEND\n my $text = qr{unterminated\n", .required_scopes = &.{ .keyword, .namespace, .function, .parameter, .variable, .string, .special, .label } },
        .multiline = .{ .source = "package First;\nsub first { 1 }\npackage Second;\nsub second { 2 }\n", .required_scopes = &.{ .keyword, .namespace, .function, .number } },
        .escapable = .{ .source = "sub run ($value) { say \"<&>\\q'\"; } # comment", .required_scopes = &.{ .keyword, .function, .parameter, .variable, .builtin, .string, .escape, .comment } },
    });
}

test "Perl parser classifies declarations regexes heredocs and POD" {
    const source = @embedFile("corpus/perl/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "Demo::Worker", .namespace);
    try expect(source, sink.captures(), "strict", .namespace);
    try expect(source, sink.captures(), "run", .function);
    try expect(source, sink.captures(), "$input", .parameter);
    try expect(source, sink.captures(), "%opts", .parameter);
    try expect(source, sink.captures(), "qr/^[a-z]+$/i", .string);
    try expect(source, sink.captures(), "qr", .special);
    try expect(source, sink.captures(), "s/foo/bar/g", .string);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "say", .builtin);
    try expect(source, sink.captures(), "MESSAGE", .label);
    try expect(source, sink.captures(), "HEADER", .label);
    try expect(source, sink.captures(), "FOOTER", .label);
    try expect(source, sink.captures(), "/missing/", .string);
    try expectNo(source, sink.captures(), "/", .string);
    try expect(source, sink.captures(), "=pod\nWorker documentation.\n=cut", .documentation);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectNo(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return error.TestUnexpectedResult;
}
