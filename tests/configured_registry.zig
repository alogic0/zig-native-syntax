const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");

test "configured registry exposes verified core and enabled external backends" {
    try std.testing.expect(registry.backends.len > 0);
    try std.testing.expectEqualStrings("zig", registry.backendForName("zig").?.info.canonical_name);

    for (registry.backends, 0..) |backend, index| {
        try std.testing.expect(backend.info.support_level != .experimental);
        try std.testing.expectEqualStrings(
            backend.info.canonical_name,
            registry.backendForName(backend.info.canonical_name).?.info.canonical_name,
        );
        for (registry.backends[index + 1 ..]) |other| {
            try std.testing.expect(!std.ascii.eqlIgnoreCase(
                backend.info.canonical_name,
                other.info.canonical_name,
            ));
        }
    }
}

test "configured registry owns core and external aliases" {
    for (syntax.aliases) |entry| {
        if (registry.backendForName(entry.canonical)) |canonical| {
            try std.testing.expectEqualStrings(
                canonical.info.canonical_name,
                registry.backendForName(entry.alias).?.info.canonical_name,
            );
        } else {
            try std.testing.expectEqual(null, registry.backendForName(entry.alias));
        }
    }
    try std.testing.expectEqual(null, registry.backendForName("unknown-language"));
}
