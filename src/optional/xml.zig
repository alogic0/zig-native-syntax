const core = @import("native_syntax");
const markup = @import("native_syntax_html_markup");

pub const backend: core.Backend = .init(.{
    .canonical_name = "xml",
    .display_name = "XML",
    .kind = .lexical,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    try markup.highlight(source, .xml, sink);
}
