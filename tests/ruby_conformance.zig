const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Ruby backend conforms" {
    try h.expect(s.languages.ruby.backend, @embedFile("corpus/ruby/complete.rb"), &.{ .keyword, .string, .escape, .number, .boolean, .comment, .function }, "x = \"<&>\\\"'\" # comment");
}
