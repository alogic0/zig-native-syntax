const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");

test "configured registry exposes verified core and enabled external backends" {
    try std.testing.expect(registry.backends.len > 0);
    try std.testing.expectEqualStrings("zig", registry.backendForName("zig").?.info.canonical_name);

    for (registry.backends, 0..) |backend, index| {
        try std.testing.expect(backend.info.support_level != .experimental);
        try std.testing.expectEqualStrings(
            backend.info.canonical_name,
            registry.backendForName(backend.info.canonical_name).?.info.canonical_name,
        );
        for (registry.backends[index + 1 ..]) |other| {
            try std.testing.expect(!std.ascii.eqlIgnoreCase(
                backend.info.canonical_name,
                other.info.canonical_name,
            ));
        }
    }
}

test "configured registry owns core and external aliases" {
    for (syntax.aliases) |entry| {
        if (registry.backendForName(entry.canonical)) |canonical| {
            try std.testing.expectEqualStrings(
                canonical.info.canonical_name,
                registry.backendForName(entry.alias).?.info.canonical_name,
            );
        } else {
            try std.testing.expectEqual(null, registry.backendForName(entry.alias));
        }
    }
    try std.testing.expectEqual(null, registry.backendForName("unknown-language"));
}

test "every configured backend tolerates adversarial source" {
    const malformed_utf8 = [_]u8{
        0xff, 0xc0, 0xaf, 0xe2, 0x82, 0xf0, 0x9f, 0x92, 0x80,
    };
    const cases = [_][]const u8{
        &malformed_utf8,
        "\"unterminated\\",
        "'unterminated\\",
        "`unterminated ${value",
        "/* /* /* nested but never closed",
        "<!-- <tag attr=\"unterminated",
        "(((([[[{{{value}}]]",
        "${${${${value}}",
        "├── valid Unicode between delimiters (\"value\")",
    };

    for (registry.backends) |backend| {
        for (cases) |source| try expectSafeAndDeterministic(backend, source);
    }
}

fn expectSafeAndDeterministic(backend: syntax.Backend, source: []const u8) !void {
    var first: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer first.deinit();
    try backend.highlight(source, &first);

    var second: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer second.deinit();
    try backend.highlight(source, &second);

    try std.testing.expectEqual(first.captures().len, second.captures().len);
    for (first.captures(), second.captures()) |left, right| {
        try std.testing.expectEqual(left.span.start, right.span.start);
        try std.testing.expectEqual(left.span.end, right.span.end);
        try std.testing.expectEqual(left.scope, right.scope);
        try left.validate(source.len);
    }

    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(
        source,
        first.captures(),
        std.testing.allocator,
        &output.writer,
    );
    if (std.unicode.utf8ValidateSlice(source)) {
        try std.testing.expect(std.unicode.utf8ValidateSlice(output.written()));
    }
}
