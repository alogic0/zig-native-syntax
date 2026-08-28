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
    .{ .alias = "nixos", .canonical = "nix" },
    .{ .alias = "fish-shell", .canonical = "fish" },
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

/// Collects verified backends while omitting a comma-separated set of
/// canonical names. This exists for link-time code-size analysis; normal
/// registries pass an empty exclusion list and include every verified backend.
pub fn collectVerifiedExcept(comptime namespace: type, comptime excluded: []const u8) [verifiedCountExcept(namespace, excluded)]Backend {
    @setEvalBranchQuota(100_000);
    var result: [verifiedCountExcept(namespace, excluded)]Backend = undefined;
    var index: usize = 0;
    inline for (std.meta.declarations(namespace)) |declaration| {
        const language = @field(namespace, declaration);
        if (@hasDecl(language, "backend") and
            language.backend.info.support_level != .experimental and
            !nameInList(language.backend.info.canonical_name, excluded))
        {
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

fn verifiedCountExcept(comptime namespace: type, comptime excluded: []const u8) comptime_int {
    @setEvalBranchQuota(100_000);
    var count = 0;
    for (std.meta.declarations(namespace)) |declaration| {
        const language = @field(namespace, declaration);
        if (@hasDecl(language, "backend") and
            language.backend.info.support_level != .experimental and
            !nameInList(language.backend.info.canonical_name, excluded)) count += 1;
    }
    return count;
}

fn nameInList(comptime name: []const u8, comptime list: []const u8) bool {
    var start: usize = 0;
    while (start <= list.len) {
        const relative_end = std.mem.indexOfScalarPos(u8, list, start, ',') orelse list.len;
        const candidate = std.mem.trim(u8, list[start..relative_end], " \t");
        if (std.mem.eql(u8, name, candidate)) return true;
        if (relative_end == list.len) break;
        start = relative_end + 1;
    }
    return false;
}
