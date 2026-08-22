const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.rust.backend;

test "Rust backend metadata is stable" {
    try std.testing.expectEqualStrings("rust", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
}

test "Rust parser conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'f', 'n', ' ', 0xff, '(', ')', ' ', '{', '}' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source =
            \\/// Documentation.
            \\#[derive(Debug)]
            \\pub fn show<'a>(value: &'a str) -> bool {
            \\    println!("value={value}\\n");
            \\    value.len() > 0 && true
            \\}
            ,
            .required_scopes = &.{
                .comment,  .documentation, .attribute, .keyword, .label,  .type,
                .builtin,  .macro,         .string,    .escape,  .number, .boolean,
                .operator, .punctuation,   .variable,
            },
        },
        .malformed = .{
            .source = "fn main() { let text = r###\"unterminated <&>\n",
            .required_scopes = &.{ .keyword, .variable, .punctuation, .operator, .string },
        },
        .multiline = .{
            .source = "/* outer\n /* nested */\n end */\nfn done() {}\n",
            .required_scopes = &.{ .comment, .keyword, .function },
        },
        .escapable = .{
            .source = "const HTML: &str = r#\"<tag title='x'>&\\\"\"#;",
            .required_scopes = &.{ .keyword, .type, .string },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .punctuation },
        },
    });
}

test "Rust scanner distinguishes characters and lifetimes" {
    const source = "fn borrow<'a>(x: &'a str) -> char { 'x' }";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "'a", .label);
    try expectCapture(source, sink.captures(), "'x'", .string);
    try expectCapture(source, sink.captures(), "str", .type);
    try expectCapture(source, sink.captures(), "char", .type);
}

test "Rust corpus covers nested comments and string forms" {
    const source = @embedFile("corpus/rust/complete.rs");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "/* outer /* nested */ complete */", .comment);
    try expectCapture(source, sink.captures(), "br##\"byte raw <&>\"##", .string);
    try expectCapture(source, sink.captures(), "b'Z'", .string);
    try expectCapture(source, sink.captures(), "vec!", .macro);
}

test "Rust parser classifies structural identifier roles" {
    const source =
        \\mod model { struct Entry { value: u64 } }
        \\fn render(entry: Entry) { let count = entry.value; consume(count); }
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "model", .namespace);
    try expectCapture(source, sink.captures(), "Entry", .type);
    try expectCapture(source, sink.captures(), "value", .property);
    try expectCapture(source, sink.captures(), "render", .function);
    try expectCapture(source, sink.captures(), "entry", .parameter);
    try expectCapture(source, sink.captures(), "count", .variable);
    try expectCapture(source, sink.captures(), "consume", .function);
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
