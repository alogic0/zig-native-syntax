const core = @import("native_syntax");
const markdown = @import("markdown");

pub const backend: core.Backend = .init(.{
    .canonical_name = "markdown",
    .display_name = "Markdown",
    .kind = .parser_backed,
    .support_level = .verified_structural,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    if (source.len == 0 or source.len > std.math.maxInt(u32)) return;

    var parser = try markdown.Parser.init(sink.allocator);
    defer parser.deinit();
    try parser.feed(source);

    var document = try parser.endInput();
    defer document.deinit(sink.allocator);

    for (0..document.nodeCount()) |ordinal| {
        const view = document.nodeAt(ordinal).?;
        switch (view.tag) {
            .heading => try addSpan(view.span, .markup_heading, sink),
            .blockquote => try addSpan(view.span, .markup_quote, sink),
            .strong => try addSpan(view.span, .markup_strong, sink),
            .emphasis => try addSpan(view.span, .markup_emphasis, sink),
            .strikethrough => try addSpan(view.span, .markup_strikethrough, sink),
            .link, .image, .footnote_definition, .footnote_reference => try addSpan(view.span, .markup_link, sink),
            .code_block, .code_span => try addSpan(view.span, .markup_code, sink),
            .html_block, .html_inline => try addSpan(view.span, .embedded, sink),
            .thematic_break => try addSpan(view.span, .special, sink),
            .line_break => try addSpan(view.span, .escape, sink),
            .list_item => try addListMarkers(source, view, sink),
            else => {},
        }
    }
}

const std = @import("std");

fn addSpan(
    span: markdown.Source.Span,
    scope: core.Scope,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    try sink.add(span.start, span.end, scope);
}

fn addListMarkers(
    source: []const u8,
    view: markdown.Document.Node.View,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    const start: usize = view.span.start;
    const limit: usize = @min(view.span.end, source.len);
    if (start >= limit) return;

    var marker_end = start;
    if (std.ascii.isDigit(source[marker_end])) {
        while (marker_end < limit and std.ascii.isDigit(source[marker_end])) {
            marker_end += 1;
        }
        if (marker_end < limit and (source[marker_end] == '.' or source[marker_end] == ')')) {
            marker_end += 1;
        }
    } else if (source[marker_end] == '-' or
        source[marker_end] == '*' or
        source[marker_end] == '+')
    {
        marker_end += 1;
    }
    if (marker_end > start) try sink.add(start, marker_end, .markup_list);

    if (view.data.list_item.task == .none) return;
    var task_start = marker_end;
    while (task_start < limit and (source[task_start] == ' ' or source[task_start] == '\t')) {
        task_start += 1;
    }
    if (task_start + 3 <= limit and
        source[task_start] == '[' and
        source[task_start + 2] == ']')
    {
        try sink.add(task_start, task_start + 3, .markup_list);
    }
}
