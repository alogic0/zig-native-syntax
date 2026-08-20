const std = @import("std");

/// Removes library-generated spans, decodes supported entities, and returns
/// the exact source bytes represented by rendered highlighting output.
/// Unknown markup and entities are rejected rather than treated as source.
pub fn recoverSource(
    allocator: std.mem.Allocator,
    rendered: []const u8,
) ![]u8 {
    var recovered: std.ArrayList(u8) = .empty;
    errdefer recovered.deinit(allocator);

    var index: usize = 0;
    while (index < rendered.len) {
        const remaining = rendered[index..];

        if (std.mem.startsWith(u8, remaining, "<span class=\"syntax-")) {
            const tag_end = std.mem.indexOfScalar(u8, remaining, '>') orelse {
                return error.UnterminatedGeneratedSpan;
            };
            index += tag_end + 1;
            continue;
        }
        if (std.mem.startsWith(u8, remaining, "</span>")) {
            index += "</span>".len;
            continue;
        }

        const entities = [_]struct { []const u8, u8 }{
            .{ "&amp;", '&' },
            .{ "&lt;", '<' },
            .{ "&gt;", '>' },
            .{ "&quot;", '"' },
            .{ "&#39;", '\'' },
        };
        for (entities) |entity| {
            if (std.mem.startsWith(u8, remaining, entity[0])) {
                try recovered.append(allocator, entity[1]);
                index += entity[0].len;
                break;
            }
        } else {
            if (rendered[index] == '<' or rendered[index] == '&') {
                return error.UnexpectedGeneratedMarkup;
            }
            try recovered.append(allocator, rendered[index]);
            index += 1;
        }
    }

    return recovered.toOwnedSlice(allocator);
}
