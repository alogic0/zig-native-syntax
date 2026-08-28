const std = @import("std");
const s = @import("native_syntax");
const c = @import("support/backend_conformance.zig");
const backend = s.languages.proto.backend;

test "Protocol Buffers metadata and structural roles are stable" {
    try std.testing.expectEqual(s.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);
    const source = "package demo.api; message Entry { string name = 1; Status state = 2; } enum Status { READY = 0; } service Store { rpc Get(Entry) returns (Entry); }";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "demo", .namespace);
    try expectCapture(source, sink.captures(), "Entry", .type);
    try expectCapture(source, sink.captures(), "name", .property);
    try expectCapture(source, sink.captures(), "READY", .constant);
    try expectCapture(source, sink.captures(), "Get", .function);
}

test "Protocol Buffers backend conforms" {
    try c.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/proto/complete.proto"), .required_scopes = &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .property } },
        .malformed = .{ .source = "message Broken { string name = \"unterminated\\n<&>\n", .required_scopes = &.{ .keyword, .type, .property, .string, .escape } },
        .multiline = .{ .source = "message Entry {\n  string name = 1;\n}\n", .required_scopes = &.{ .keyword, .type, .property } },
        .escapable = .{ .source = "string value = \"<&>\\\"'\"; // comment", .required_scopes = &.{ .type, .property, .string, .escape, .comment } },
        .extra_cases = &.{.{ .source = @embedFile("corpus/proto/service.proto"), .required_scopes = &.{ .namespace, .type, .function, .property, .constant } }},
    });
}

fn expectCapture(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
