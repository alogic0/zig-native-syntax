const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Ruby backend conforms" {
    const backend = s.languages.ruby.backend;
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);
    try h.expect(backend, @embedFile("corpus/ruby/complete.rb"), &.{ .keyword, .string, .escape, .number, .boolean, .comment, .function }, "x = \"<&>\\\"'\" # comment");
    const source = "module Demo; class Worker; def run(value); @value = value; end; end; end";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "Demo", .namespace);
    try expect(source, sink.captures(), "Worker", .type);
    try expect(source, sink.captures(), "run", .function);
    try expect(source, sink.captures(), "value", .parameter);
    try expect(source, sink.captures(), "@value", .variable);
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
