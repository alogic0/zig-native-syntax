const std = @import("std");
const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "PHP backend conforms" {
    try h.expect(s.languages.php.backend, @embedFile("corpus/php/complete.php"), &.{ .embedded, .special, .tag, .attribute, .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .variable, .parameter, .property, .constructor }, "$x = \"<&>\\\"'\"; // comment");
}

test "PHP separates markup and structural PHP roles" {
    const source = "<main class=\"card\"><?php class Greeter { function greet(string $name) { return $this->format($name); } } $item = new Greeter(); ?></main>";
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try s.languages.php.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "main", .tag);
    try expect(source, sink.captures(), "class", .attribute);
    try expect(source, sink.captures(), "Greeter", .type);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "$name", .parameter);
    try expect(source, sink.captures(), "$this", .variable);
    try expect(source, sink.captures(), "format", .function);
    try expect(source, sink.captures(), "Greeter", .constructor);
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}
