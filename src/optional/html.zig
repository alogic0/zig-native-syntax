const core = @import("native_syntax");
const markup = @import("native_syntax_html_markup");

pub const backend: core.Backend = .init(.{
    .canonical_name = "html",
    .display_name = "HTML",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    try markup.highlight(source, .html, sink);
}
