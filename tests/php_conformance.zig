const std = @import("std");
const s = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
test "PHP backend conforms" {
    try conformance.expectConforms(s.languages.php.backend, .{
        .valid = .{ .source = @embedFile("corpus/php/complete.php"), .required_scopes = &.{ .embedded, .special, .tag, .attribute, .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .variable, .parameter, .property, .constructor } },
        .malformed = .{ .source = "$value = \"unterminated\\u12<&>\nnext = true\n", .required_scopes = &.{ .embedded, .variable, .string, .escape } },
        .multiline = .{ .source = "$first = 1;\n$second = 2;\n", .required_scopes = &.{ .embedded, .variable, .number } },
        .escapable = .{ .source = "$x = \"<&>\\\"'\"; // comment", .required_scopes = &.{ .embedded, .variable, .string, .escape, .comment } },
    });
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

test "PHP handles framework attributes namespaces closures heredocs and embedded close text" {
    const source = @embedFile("corpus/php/framework.php");
    var sink: s.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try s.languages.php.backend.highlight(source, &sink);

    try expect(source, sink.captures(), "App", .namespace);
    try expect(source, sink.captures(), "Controllers", .namespace);
    try expect(source, sink.captures(), "Route", .attribute);
    try expect(source, sink.captures(), "UserController", .type);
    try expect(source, sink.captures(), "__invoke", .function);
    try expect(source, sink.captures(), "$request", .parameter);
    try expect(source, sink.captures(), "$user", .parameter);
    try expect(source, sink.captures(), "<<<HTML\n<section><?= $request->name ?></section>\nHTML;", .string);
    try expect(source, sink.captures(), "'not ?> closed'", .string);
    try std.testing.expectEqual(@as(usize, 1), count(source, sink.captures(), "?>", .special));
    try expect(source, sink.captures(), "footer", .tag);
}

fn expect(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn count(source: []const u8, captures: []const s.Capture, text: []const u8, scope: s.Scope) usize {
    var result: usize = 0;
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, capture.span.slice(source) catch continue, text)) {
        result += 1;
    };
    return result;
}
