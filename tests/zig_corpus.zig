const std = @import("std");
const syntax = @import("native_syntax");

const complete = @embedFile("corpus/zig/complete.zig");
const malformed = @embedFile("corpus/zig/malformed.zig.txt");
const incomplete = @embedFile("corpus/zig/incomplete.zig.txt");
const golden = @embedFile("corpus/zig/golden.zig");

fn classifyAndRender(source: []const u8) ![]u8 {
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try syntax.languages.zig.backend.highlight(source, &sink);

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    errdefer output.deinit();
    try syntax.html.render(
        source,
        sink.captures(),
        std.testing.allocator,
        &output.writer,
    );
    return output.toOwnedSlice();
}

fn hasCapture(
    captures: []const syntax.Capture,
    source: []const u8,
    expected_source: []const u8,
    expected_scope: syntax.Scope,
) bool {
    for (captures) |capture| {
        if (capture.scope == expected_scope and
            std.mem.eql(u8, capture.span.slice(source) catch return false, expected_source))
        {
            return true;
        }
    }
    return false;
}

fn hasScope(captures: []const syntax.Capture, expected_scope: syntax.Scope) bool {
    for (captures) |capture| {
        if (capture.scope == expected_scope) return true;
    }
    return false;
}

test "Zig corpus highlights complete, malformed, and incomplete source" {
    const cases = [_][]const u8{ complete, malformed, incomplete };
    for (cases) |source| {
        const rendered = try classifyAndRender(source);
        defer std.testing.allocator.free(rendered);
        try std.testing.expect(rendered.len >= source.len);
    }
}

test "complete Zig corpus covers representative classifications" {
    var sink: syntax.CaptureSink = .init(std.testing.allocator, complete.len);
    defer sink.deinit();
    try syntax.languages.zig.backend.highlight(complete, &sink);

    const captures = sink.captures();
    try std.testing.expect(hasCapture(captures, complete, "//! A representative complete Zig source file.", .documentation));
    try std.testing.expect(hasCapture(captures, complete, "// Exercise calls, field access, builtins, and operators.", .comment));
    try std.testing.expect(hasCapture(captures, complete, "Point", .type));
    try std.testing.expect(hasCapture(captures, complete, "length", .function));
    try std.testing.expect(hasCapture(captures, complete, "self", .parameter));
    try std.testing.expect(hasCapture(captures, complete, "x", .property));
    try std.testing.expect(hasCapture(captures, complete, "@sqrt", .builtin));
    try std.testing.expect(hasCapture(captures, complete, "\\\\first <line>", .string));
    try std.testing.expect(hasCapture(captures, complete, "5", .number));
    try std.testing.expect(hasCapture(captures, complete, "==", .operator));
}

test "malformed and incomplete corpus retain useful lexical captures" {
    var malformed_sink: syntax.CaptureSink = .init(std.testing.allocator, malformed.len);
    defer malformed_sink.deinit();
    try syntax.languages.zig.backend.highlight(malformed, &malformed_sink);
    try std.testing.expect(hasCapture(malformed_sink.captures(), malformed, "before", .variable));
    try std.testing.expect(hasScope(malformed_sink.captures(), .invalid));
    try std.testing.expect(hasCapture(malformed_sink.captures(), malformed, "after", .variable));

    var incomplete_sink: syntax.CaptureSink = .init(std.testing.allocator, incomplete.len);
    defer incomplete_sink.deinit();
    try syntax.languages.zig.backend.highlight(incomplete, &incomplete_sink);
    try std.testing.expect(hasCapture(incomplete_sink.captures(), incomplete, "incomplete", .variable));
    try std.testing.expect(hasCapture(incomplete_sink.captures(), incomplete, "value", .variable));
    try std.testing.expect(hasCapture(incomplete_sink.captures(), incomplete, "pending", .variable));
    try std.testing.expect(hasCapture(incomplete_sink.captures(), incomplete, "call", .variable));
}

test "Zig rendering has deterministic golden markup" {
    const rendered = try classifyAndRender(golden);
    defer std.testing.allocator.free(rendered);

    try std.testing.expectEqualStrings(
        "<span class=\"syntax-keyword\">const</span> " ++
            "<span class=\"syntax-type syntax-variable\">Box</span> " ++
            "<span class=\"syntax-operator\">=</span> " ++
            "<span class=\"syntax-keyword\">struct</span> " ++
            "<span class=\"syntax-punctuation\">{</span> " ++
            "<span class=\"syntax-property syntax-variable\">value</span>" ++
            "<span class=\"syntax-punctuation\">:</span> " ++
            "<span class=\"syntax-builtin syntax-type\">u8</span> " ++
            "<span class=\"syntax-punctuation\">}</span>" ++
            "<span class=\"syntax-punctuation\">;</span>\n",
        rendered,
    );
}
