const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "asm", .display_name = "Assembly", .kind = .lexical, .support_level = .verified_lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{"#"}, .keywords = &.{ "add", "and", "bl", "call", "cmp", "jmp", "ldr", "lea", "mov", "mul", "nop", "or", "pop", "push", "ret", "str", "sub", "test", "xor" }, .types = &.{ "eax", "ebp", "ebx", "ecx", "edi", "edx", "esi", "esp", "rax", "rbp", "rbx", "rcx", "rdi", "rdx", "rsi", "rsp", "x0", "x1", "x2", "x3" } });
}
