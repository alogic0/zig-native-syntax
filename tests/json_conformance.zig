const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.json.backend;

test "JSON backend metadata is stable" {
    try std.testing.expectEqualStrings("json", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "JSON scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ '{', '"', 'x', '"', ':', '"', 0xff, '"', '}' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source =
            \\{"name":"Zig","ok":true,"missing":null,"values":[-1,2.5e3]}
            ,
            .required_scopes = &.{ .property, .string, .boolean, .constant, .number, .punctuation },
        },
        .malformed = .{
            .source = "{\"unfinished\": \"text\\u12<&>\n",
            .required_scopes = &.{ .property, .string, .escape, .punctuation },
        },
        .multiline = .{
            .source = "{\n  \"array\": [true, false, null]\n}\n",
            .required_scopes = &.{ .property, .boolean, .constant, .punctuation },
        },
        .escapable = .{
            .source = "{\"html\":\"<&>\\\"'\"}",
            .required_scopes = &.{ .property, .string, .escape },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .property, .string, .punctuation },
        },
        .extra_cases = &.{
            .{
                .source = "[tru",
                .required_scopes = &.{ .boolean, .punctuation },
            },
            .{
                .source = "[-, 1., 2e+]",
                .required_scopes = &.{ .number, .punctuation },
            },
        },
    });
}

test "JSON complete corpus agrees with the standard scanner" {
    const source = @embedFile("corpus/json/complete.json");
    try std.testing.expect(try std.json.validate(std.testing.allocator, source));

    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "\"name\"", .property);
    try expectCapture(source, sink.captures(), "\"zig-native-syntax\"", .string);
    try expectCapture(source, sink.captures(), "\\u03bb", .escape);
    try expectCapture(source, sink.captures(), "6.02e23", .number);
    try expectCapture(source, sink.captures(), "true", .boolean);
    try expectCapture(source, sink.captures(), "null", .constant);
}

test "JSON scanner leaves JSON5-only syntax unclassified" {
    const source = "// comment\n{unquoted: 'value'}";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try std.testing.expect(!hasScope(sink.captures(), .comment));
    try std.testing.expect(!hasScope(sink.captures(), .property));
    try std.testing.expect(!hasScope(sink.captures(), .string));
    try std.testing.expect(hasScope(sink.captures(), .punctuation));
}

fn expectCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| {
        if (capture.scope == expected) return true;
    }
    return false;
}
