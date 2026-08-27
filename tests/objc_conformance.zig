const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Objective-C backend conforms" {
    try h.expect(s.languages.objc.backend, @embedFile("corpus/objc/complete.m"), &.{ .macro, .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .parameter, .property }, "id x = \"<&>\\\"'\"; // comment");
}

test "Objective-C parser distinguishes declarations and selectors" {
    const source =
        "@interface Greeter : NSObject\n" ++
        "@property(nonatomic, copy) NSString *prefix;\n" ++
        "- (NSString *)greet:(NSString *)name count:(NSInteger)count;\n" ++
        "@end\n" ++
        "NSString *message = [greeter greet:@\"Ada\" count:2];";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try s.languages.objc.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "@interface", .keyword);
    try expect(source, sink.captures(), "Greeter", .type);
    try expect(source, sink.captures(), "prefix", .property);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "name", .parameter);
    try expect(source, sink.captures(), "count", .parameter);
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
