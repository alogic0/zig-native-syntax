const api = @import("../backend.zig");
const g = @import("generic.zig");
const structure = @import("structured_c_like.zig");

const keywords = &.{ "alignas", "auto", "break", "case", "catch", "class", "concept", "const", "constexpr", "continue", "co_await", "co_return", "co_yield", "decltype", "default", "delete", "do", "else", "enum", "explicit", "export", "extern", "for", "friend", "if", "inline", "namespace", "new", "noexcept", "operator", "private", "protected", "public", "requires", "return", "sizeof", "static", "struct", "switch", "template", "this", "throw", "try", "typedef", "typename", "union", "using", "virtual", "volatile", "while" };
const types = &.{ "bool", "char", "char8_t", "double", "float", "int", "long", "short", "signed", "unsigned", "void", "wchar_t", "size_t" };

pub const backend: api.Backend = .init(.{
    .canonical_name = "cpp",
    .display_name = "C++",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{
        .line_comments = &.{"//"},
        .block_comments = &.{.{ .open = "/*", .close = "*/" }},
        .keywords = keywords,
        .types = types,
        .preprocessor = true,
        .classify_identifiers = false,
    });
    try structure.highlight(source, sink, .{
        .keywords = keywords,
        .builtin_types = types,
        .modifiers = &.{ "const", "constexpr", "explicit", "extern", "friend", "inline", "mutable", "static", "thread_local", "typedef", "virtual", "volatile" },
        .type_declarations = &.{ "class", "enum", "struct", "union", "using" },
        .namespace_declarations = &.{"namespace"},
    });
}
