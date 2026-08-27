const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "PowerShell backend conforms" {
    const backend = s.languages.powershell.backend;
    try std.testing.expectEqual(s.SupportLevel.verified_structural, backend.info.support_level);
    try h.expect(backend, @embedFile("corpus/powershell/complete.ps1"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .variable }, "$x = \"<&>\\\"'\" # comment");
    const source = "function Invoke-Demo { param([string]$Name) } class Worker {}";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    try expect(source, sink.captures(), "Invoke-Demo", .function);
    try expect(source, sink.captures(), "Worker", .type);
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
