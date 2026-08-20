/// Returns the length of the dummy language's leading keyword.
pub fn keywordLength(source: []const u8) usize {
    const keyword = "dummy";
    if (source.len < keyword.len) return 0;
    return if (std.mem.eql(u8, source[0..keyword.len], keyword)) keyword.len else 0;
}

const std = @import("std");
