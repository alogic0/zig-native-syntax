const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");

test "analysis registry links only requested experimental backends" {
    try std.testing.expect(registry.analysis_mode);
    const nasm_backend = registry.backendForName("nasm").?;
    try std.testing.expectEqual(syntax.SupportLevel.experimental, nasm_backend.info.support_level);
    try std.testing.expectEqualStrings("nasm", nasm_backend.info.canonical_name);

    try std.testing.expectEqual(null, registry.backendForName("dtd"));
    try std.testing.expectEqualStrings("zig", registry.backendForName("zig").?.info.canonical_name);
}
