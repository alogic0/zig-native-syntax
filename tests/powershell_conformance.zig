const s = @import("native_syntax");
const h = @import("support/roadmap_conformance.zig");
test "PowerShell backend conforms" {
    try h.expect(s.languages.powershell.backend, @embedFile("corpus/powershell/complete.ps1"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment, .function, .variable }, "$x = \"<&>\\\"'\" # comment");
}
