const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "Lua backend conforms" {
    try h.expect(s.languages.lua.backend, @embedFile("corpus/lua/complete.lua"), &.{ .keyword, .string, .escape, .number, .boolean, .comment, .function }, "local x = \"<&>\\\"'\" -- comment");
}
