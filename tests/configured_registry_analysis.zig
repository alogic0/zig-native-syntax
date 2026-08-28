const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");

test "analysis registry does not duplicate verified inclusions" {
    try std.testing.expect(registry.analysis_mode);
    try std.testing.expectEqual(registry.core_catalog_count, registry.backends.len);
    const dtd_backend = registry.backendForName("dtd").?;
    try std.testing.expectEqual(syntax.SupportLevel.verified_lexical, dtd_backend.info.support_level);
    try std.testing.expectEqualStrings("dtd", dtd_backend.info.canonical_name);

    try std.testing.expectEqualStrings("comment", registry.backendForName("comment").?.info.canonical_name);
    try std.testing.expectEqualStrings("zig", registry.backendForName("zig").?.info.canonical_name);
}
