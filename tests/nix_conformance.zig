const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Nix backend conforms" {
    try helper.expect(syntax.languages.nix.backend, @embedFile("corpus/nix/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
