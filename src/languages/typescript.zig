const backend_api = @import("../backend.zig");
const javascript = @import("javascript.zig");

pub const backend: backend_api.Backend = .init(.{
    .canonical_name = "typescript",
    .display_name = "TypeScript",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *backend_api.CaptureSink) backend_api.HighlightError!void {
    try javascript.highlightLanguage(source, sink, .typescript);
}
