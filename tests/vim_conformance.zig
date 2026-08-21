const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

test "Vimscript backend conforms" {
    try conformance.expectConforms(syntax.languages.vim.backend, .{
        .valid = .{
            .source = @embedFile("corpus/vim/complete.txt"),
            .required_scopes = &.{ .keyword, .string, .escape, .number, .boolean, .comment },
        },
        .malformed = .{
            .source = "let value = 'unterminated\\q<&>\nlet enabled = v:true\n",
            .required_scopes = &.{ .keyword, .string, .escape, .operator, .boolean },
        },
        .multiline = .{
            .source = "let first = 1\nlet second = 2\n",
            .required_scopes = &.{ .keyword, .property, .number },
        },
        .escapable = .{
            .source = "let value = '<&>\\q\"' \" comment",
            .required_scopes = &.{ .keyword, .string, .escape, .comment },
        },
    });
}
