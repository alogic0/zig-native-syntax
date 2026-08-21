const api = @import("../backend.zig");
const g = @import("generic.zig");
pub const backend: api.Backend = .init(.{ .canonical_name = "nasm", .display_name = "NASM", .kind = .lexical }, highlight);
fn highlight(s: []const u8, k: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(s, k, .{ .line_comments = &.{";"}, .keywords = &.{ "bits", "section", "global", "extern", "add", "call", "cmp", "db", "dd", "dq", "dw", "jmp", "lea", "mov", "pop", "push", "resb", "resd", "ret", "sub", "xor" }, .types = &.{ "byte", "dword", "qword", "word", "eax", "ebx", "ecx", "edx", "rax", "rbx", "rcx", "rdx", "rsp" }, .case_insensitive = true });
}
