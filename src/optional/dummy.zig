const core = @import("native_syntax");
const dummy_syntax = @import("dummy_syntax");

pub const backend: core.Backend = .init(.{
    .canonical_name = "dummy",
    .display_name = "Phase 4 Dummy",
    .kind = .parser_backed,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    const keyword_len = dummy_syntax.keywordLength(source);
    if (keyword_len != 0) try sink.add(0, keyword_len, .keyword);
}
