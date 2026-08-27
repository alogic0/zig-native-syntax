const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");

test "C++ metadata and contextual roles are stable" {
    const backend = s.languages.cpp.backend;
    try std.testing.expectEqual(s.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);

    const source = "namespace demo { class Widget { public: Widget(int size); void render(const Item &item) { helper(item.value); } }; }";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expectCapture(source, sink.captures(), "demo", .namespace);
    try expectCapture(source, sink.captures(), "Widget", .type);
    try expectCapture(source, sink.captures(), "Widget", .constructor);
    try expectCapture(source, sink.captures(), "render", .function);
    try expectCapture(source, sink.captures(), "item", .parameter);
    try expectCapture(source, sink.captures(), "value", .property);
}

test "C++ backend conforms" {
    try h.expect(s.languages.cpp.backend, @embedFile("corpus/cpp/complete.cpp"), &.{ .macro, .keyword, .type, .string, .escape, .number, .boolean, .comment, .function }, "const char* x = \"<&>\\\"'\"; // comment");
}

fn expectCapture(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
