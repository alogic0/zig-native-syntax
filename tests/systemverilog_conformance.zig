const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.systemverilog.backend;

test "SystemVerilog backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/systemverilog/complete.txt"), .required_scopes = &.{ .keyword, .namespace, .type, .function, .parameter, .property, .variable, .constant, .macro, .attribute, .string, .escape, .number, .comment } },
        .malformed = .{ .source = "`define OPEN\nmodule broken #(parameter int WIDTH = 8) (input logic clk\nfunction int run(input int value;\n", .required_scopes = &.{ .macro, .keyword, .type, .constant, .parameter, .function } },
        .multiline = .{ .source = "module demo(input logic clk);\nfunction int one(input int value); return value; endfunction\nendmodule\n", .required_scopes = &.{ .type, .function, .parameter } },
        .escapable = .{ .source = "module demo; initial $display(\"<&>\\q'\"); // comment\nendmodule", .required_scopes = &.{ .type, .function, .string, .escape, .comment } },
    });
}

test "SystemVerilog parser classifies declarations ports functions and directives" {
    const source = @embedFile("corpus/systemverilog/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "`define", .macro);
    try expect(source, sink.captures(), "DEFAULT_WIDTH", .macro);
    try expect(source, sink.captures(), "demo_pkg", .namespace);
    try expect(source, sink.captures(), "demo", .type);
    try expect(source, sink.captures(), "WIDTH", .constant);
    try expect(source, sink.captures(), "clk", .parameter);
    try expect(source, sink.captures(), "state_t", .type);
    try expect(source, sink.captures(), "IDLE", .constant);
    try expect(source, sink.captures(), "add", .function);
    try expect(source, sink.captures(), "lhs", .parameter);
    try expect(source, sink.captures(), "count", .variable);
    try expect(source, sink.captures(), "valid", .property);
    try expect(source, sink.captures(), "$display", .function);
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
