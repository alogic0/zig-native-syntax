const std = @import("std");
const backend_api = @import("backend.zig");
const Backend = backend_api.Backend;

pub const Alias = struct {
    alias: []const u8,
    canonical: []const u8,
};

/// Package-owned aliases shared by every consumer of the configured registry.
pub const aliases = [_]Alias{
    .{ .alias = "sh", .canonical = "bash" },
    .{ .alias = "shell", .canonical = "bash" },
    .{ .alias = "patch", .canonical = "diff" },
    .{ .alias = "docker", .canonical = "dockerfile" },
    .{ .alias = "yml", .canonical = "yaml" },
    .{ .alias = "py", .canonical = "python" },
    .{ .alias = "python3", .canonical = "python" },
    .{ .alias = "terraform", .canonical = "hcl" },
    .{ .alias = "makefile", .canonical = "make" },
    .{ .alias = "sshconfig", .canonical = "ssh-config" },
    .{ .alias = "git-commit", .canonical = "gitcommit" },
    .{ .alias = "gitrebase", .canonical = "git-rebase" },
    .{ .alias = "gettext", .canonical = "po" },
    .{ .alias = "js", .canonical = "javascript" },
    .{ .alias = "rs", .canonical = "rust" },
    .{ .alias = "ts", .canonical = "typescript" },
    .{ .alias = "c++", .canonical = "cpp" },
    .{ .alias = "objective-c", .canonical = "objc" },
    .{ .alias = "objectivec", .canonical = "objc" },
    .{ .alias = "obj-c", .canonical = "objc" },
    .{ .alias = "td", .canonical = "tablegen" },
    .{ .alias = "f90", .canonical = "fortran" },
    .{ .alias = "f95", .canonical = "fortran" },
    .{ .alias = "assembly", .canonical = "asm" },
    .{ .alias = "gas", .canonical = "asm" },
    .{ .alias = "ps1", .canonical = "powershell" },
    .{ .alias = "pwsh", .canonical = "powershell" },
    .{ .alias = "rb", .canonical = "ruby" },
    .{ .alias = "bat", .canonical = "batch" },
    .{ .alias = "cmd", .canonical = "batch" },
    .{ .alias = "bazel", .canonical = "starlark" },
    .{ .alias = "bzl", .canonical = "starlark" },
    .{ .alias = "console", .canonical = "shell-session" },
    .{ .alias = "sh-session", .canonical = "shell-session" },
    .{ .alias = "bash-session", .canonical = "shell-session" },
    .{ .alias = "md", .canonical = "markdown" },
    .{ .alias = "smd", .canonical = "markdown" },
    .{ .alias = "supermd", .canonical = "markdown" },
    .{ .alias = "markdown-inline", .canonical = "markdown" },
    .{ .alias = "rpm-bash", .canonical = "rpmbash" },
    .{ .alias = "csproj", .canonical = "xml" },
    .{ .alias = "props", .canonical = "xml" },
};

pub fn collectVerified(comptime namespace: type) [verifiedCount(namespace)]Backend {
    var result: [verifiedCount(namespace)]Backend = undefined;
    var index: usize = 0;
    inline for (std.meta.declarations(namespace)) |declaration| {
        const language = @field(namespace, declaration);
        if (@hasDecl(language, "backend") and language.backend.info.support_level != .experimental) {
            result[index] = language.backend;
            index += 1;
        }
    }
    return result;
}

pub fn find(name: []const u8, backends: []const Backend) ?Backend {
    const canonical = canonicalName(name);
    for (backends) |backend| {
        if (backend.info.support_level != .experimental and
            std.ascii.eqlIgnoreCase(canonical, backend.info.canonical_name)) return backend;
    }
    return null;
}

pub fn canonicalName(name: []const u8) []const u8 {
    for (aliases) |entry| {
        if (std.ascii.eqlIgnoreCase(name, entry.alias)) return entry.canonical;
    }
    return name;
}

fn verifiedCount(comptime namespace: type) comptime_int {
    var count = 0;
    for (std.meta.declarations(namespace)) |declaration| {
        const language = @field(namespace, declaration);
        if (@hasDecl(language, "backend") and language.backend.info.support_level != .experimental) count += 1;
    }
    return count;
}
