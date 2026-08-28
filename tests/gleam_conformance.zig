const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.gleam.backend;

test "Gleam backend conforms" {
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.experimental, backend.info.support_level);
    try conformance.expectConforms(backend, .{
        .valid = .{ .source = @embedFile("corpus/gleam/complete.txt"), .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment, .documentation, .attribute, .namespace, .type, .constructor, .function, .parameter, .property, .constant } },
        .malformed = .{ .source = "pub fn broken(value: String) { \"unterminated\\u12\n", .required_scopes = &.{ .keyword, .function, .parameter, .type, .string, .escape } },
        .multiline = .{ .source = "import gleam/list\npub fn first() { Person() }\npub fn second() { True }\n", .required_scopes = &.{ .namespace, .function, .constructor } },
        .escapable = .{ .source = "let value = \"<&>\\q'\" // comment", .required_scopes = &.{ .keyword, .variable, .string, .escape, .comment } },
        .extra_cases = &.{
            .{ .source = "import gleam/string as\nlet recovered = 1\n", .required_scopes = &.{ .keyword, .namespace, .variable, .number } },
            .{ .source = "pub fn broken() {\n  use value <-\n  let recovered = <<1, value:size(\n  let after = recovered.field\n}\n", .required_scopes = &.{ .keyword, .function, .parameter, .variable, .attribute, .property } },
            .{ .source = "pub fn broken(person: Person) {\n  let Person(name, = person\n  let recovered = person.name\n}\n", .required_scopes = &.{ .keyword, .function, .parameter, .type, .constructor, .variable, .property } },
        },
    });
}

test "Gleam parser classifies structural language forms" {
    const source = @embedFile("corpus/gleam/complete.txt");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expect(source, sink.captures(), "gleam/list", .namespace);
    try expect(source, sink.captures(), "Person", .type);
    try expect(source, sink.captures(), "Person", .constructor);
    try expect(source, sink.captures(), "name", .property);
    try expect(source, sink.captures(), "greet", .function);
    try expect(source, sink.captures(), "person", .parameter);
    try expect(source, sink.captures(), "prefix", .constant);
    try expect(source, sink.captures(), "@external", .attribute);
    try expect(source, sink.captures(), "text", .namespace);
    try expect(source, sink.captures(), "name", .variable);
    try expect(source, sink.captures(), "enabled", .variable);
    try expect(source, sink.captures(), "suffix", .parameter);
    try expect(source, sink.captures(), "updated", .variable);
    try expect(source, sink.captures(), "enabled", .property);
    try expect(source, sink.captures(), "try", .function);
    try expect(source, sink.captures(), "append", .function);
    try expect(source, sink.captures(), "size", .attribute);
    try expect(source, sink.captures(), "utf8", .attribute);
    try expectCount(source, sink.captures(), "list", .namespace, 1);
    try expectCount(source, sink.captures(), "result", .namespace, 1);
    try expectCount(source, sink.captures(), "text", .namespace, 3);
    try expectWithin(source, sink.captures(), "Person(..person", "person", .variable);
    try expectWithin(source, sink.captures(), "enabled: False", "enabled", .property);
}

test "Gleam structural rendering remains stable" {
    const source =
        "import gleam/string as text\n" ++
        "import gleam/result\n" ++
        "pub fn render(person: Person) -> String {\n" ++
        "  use suffix <- result.try(Ok(\"!\"))\n" ++
        "  let updated = Person(..person, enabled: False)\n" ++
        "  <<suffix:utf8>> |> text.append(suffix)\n" ++
        "}";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try syntax.html.render(source, sink.captures(), std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "<span class=\"syntax-keyword\">import</span> <span class=\"syntax-namespace\">gleam/string</span> <span class=\"syntax-keyword\">as</span> <span class=\"syntax-namespace\">text</span>\n" ++
            "<span class=\"syntax-keyword\">import</span> <span class=\"syntax-namespace\">gleam/result</span>\n" ++
            "<span class=\"syntax-keyword\">pub</span> <span class=\"syntax-keyword\">fn</span> <span class=\"syntax-function\">render</span><span class=\"syntax-punctuation\">(</span><span class=\"syntax-parameter\">person</span><span class=\"syntax-operator\">:</span> <span class=\"syntax-type\">Person</span><span class=\"syntax-punctuation\">)</span> <span class=\"syntax-operator\">-&gt;</span> <span class=\"syntax-builtin syntax-type\">String</span> <span class=\"syntax-punctuation\">{</span>\n" ++
            "  <span class=\"syntax-keyword\">use</span> <span class=\"syntax-parameter\">suffix</span> <span class=\"syntax-operator\">&lt;-</span> <span class=\"syntax-namespace\">result</span><span class=\"syntax-punctuation\">.</span><span class=\"syntax-function\">try</span><span class=\"syntax-punctuation\">(</span><span class=\"syntax-constructor\">Ok</span><span class=\"syntax-punctuation\">(</span><span class=\"syntax-string\">&quot;!&quot;</span><span class=\"syntax-punctuation\">)</span><span class=\"syntax-punctuation\">)</span>\n" ++
            "  <span class=\"syntax-keyword\">let</span> <span class=\"syntax-variable\">updated</span> <span class=\"syntax-operator\">=</span> <span class=\"syntax-constructor\">Person</span><span class=\"syntax-punctuation\">(</span><span class=\"syntax-punctuation\">.</span><span class=\"syntax-punctuation\">.</span><span class=\"syntax-variable\">person</span><span class=\"syntax-punctuation\">,</span> <span class=\"syntax-property\">enabled</span><span class=\"syntax-operator\">:</span> <span class=\"syntax-boolean\">False</span><span class=\"syntax-punctuation\">)</span>\n" ++
            "  <span class=\"syntax-operator\">&lt;&lt;</span><span class=\"syntax-variable\">suffix</span><span class=\"syntax-operator\">:</span><span class=\"syntax-attribute\">utf8</span><span class=\"syntax-operator\">&gt;&gt;</span> <span class=\"syntax-operator\">|&gt;</span> <span class=\"syntax-namespace\">text</span><span class=\"syntax-punctuation\">.</span><span class=\"syntax-function\">append</span><span class=\"syntax-punctuation\">(</span><span class=\"syntax-variable\">suffix</span><span class=\"syntax-punctuation\">)</span>\n" ++
            "<span class=\"syntax-punctuation\">}</span>",
        output.written(),
    );
}

fn expect(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    return error.TestExpectedEqual;
}

fn expectCount(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope, minimum: usize) !void {
    var count: usize = 0;
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) count += 1;
    }
    try std.testing.expect(count >= minimum);
}

fn expectWithin(source: []const u8, captures: []const syntax.Capture, context: []const u8, text: []const u8, scope: syntax.Scope) !void {
    const context_start = std.mem.indexOf(u8, source, context) orelse return error.TestExpectedEqual;
    const relative_start = std.mem.indexOf(u8, context, text) orelse return error.TestExpectedEqual;
    const start = context_start + relative_start;
    for (captures) |capture| {
        if (capture.scope == scope and capture.span.start == start and capture.span.end == start + text.len) return;
    }
    return error.TestExpectedEqual;
}
