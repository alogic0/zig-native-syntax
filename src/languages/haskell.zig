const api = @import("../backend.zig");
const family = @import("elm_purescript.zig");
const generic = @import("generic.zig");

pub const backend: api.Backend = .init(.{
    .canonical_name = "haskell",
    .display_name = "Haskell",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try generic.highlight(source, sink, .{
        .line_comments = &.{"--"},
        .block_comments = &.{.{ .open = "{-", .close = "-}" }},
        .nested_block_comments = true,
        .keywords = &.{ "as", "case", "class", "data", "default", "deriving", "do", "else", "family", "foreign", "hiding", "if", "import", "in", "infix", "infixl", "infixr", "instance", "let", "module", "newtype", "of", "qualified", "then", "type", "where" },
        .types = &.{ "Bool", "Char", "Double", "Either", "Float", "IO", "Int", "Integer", "Maybe", "Ordering", "String", "Text", "Word" },
        .constants = &.{"Nothing"},
        .booleans = &.{ "True", "False" },
        .classify_identifiers = false,
        .identifier_dash = false,
    });
    try family.highlight(source, sink, .haskell);
}
