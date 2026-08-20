const std = @import("std");
const core = @import("native_syntax");
const scripty_backend = @import("native_syntax_scripty").backend;
const super = @import("superhtml");
const markup = @import("html_markup.zig");

pub const backend: core.Backend = .init(.{
    .canonical_name = "superhtml",
    .display_name = "SuperHTML",
    .kind = .composed,
}, highlight);

fn highlight(source: []const u8, sink: *core.CaptureSink) core.HighlightError!void {
    if (source.len > std.math.maxInt(u32)) return;

    var regions: std.ArrayList(core.Span) = .empty;
    defer regions.deinit(sink.allocator);
    var directives: std.ArrayList(core.Span) = .empty;
    defer directives.deinit(sink.allocator);
    try findScriptyRegions(source, sink.allocator, &regions, &directives);

    var markup_sink: core.CaptureSink = .init(sink.allocator, source.len);
    defer markup_sink.deinit();
    try markup.highlight(source, .superhtml, &markup_sink);
    try copyMarkupCaptures(markup_sink.captures(), regions.items, sink);

    for (directives.items) |directive| {
        try sink.add(directive.start, directive.end, .special);
    }
    for (regions.items) |region| {
        try core.composition.highlightEmbedded(source, region, scripty_backend, sink);
    }
}

fn findScriptyRegions(
    source: []const u8,
    allocator: std.mem.Allocator,
    regions: *std.ArrayList(core.Span),
    directives: *std.ArrayList(core.Span),
) std.mem.Allocator.Error!void {
    var tokenizer: super.html.Tokenizer = .{
        .language = .superhtml,
        .return_attrs = true,
    };
    while (tokenizer.next(source)) |token| switch (token) {
        .attr => |attribute| {
            const name = attribute.name.slice(source);
            const directive = isDirective(name);
            if (directive) {
                try directives.append(allocator, .{
                    .start = attribute.name.start,
                    .end = attribute.name.end,
                });
            }

            const value = attribute.value orelse continue;
            const value_source = value.span.slice(source);
            if ((directive and !std.mem.eql(u8, name, ":else")) or
                std.mem.startsWith(u8, value_source, "$"))
            {
                try regions.append(allocator, .{
                    .start = value.span.start,
                    .end = value.span.end,
                });
            }
        },
        else => {},
    };
}

fn isDirective(name: []const u8) bool {
    return std.mem.eql(u8, name, ":if") or
        std.mem.eql(u8, name, ":loop") or
        std.mem.eql(u8, name, ":else") or
        std.mem.eql(u8, name, ":text") or
        std.mem.eql(u8, name, ":html");
}

fn copyMarkupCaptures(
    captures: []const core.Capture,
    regions: []const core.Span,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    for (captures) |capture| {
        if (capture.scope != .string) {
            try sink.addCapture(capture);
            continue;
        }

        const region = containingRegion(capture.span, regions) orelse {
            try sink.addCapture(capture);
            continue;
        };
        try sink.add(capture.span.start, region.start, .string);
        try sink.add(region.end, capture.span.end, .string);
    }
}

fn containingRegion(parent: core.Span, regions: []const core.Span) ?core.Span {
    for (regions) |region| {
        if (parent.start <= region.start and parent.end >= region.end) return region;
    }
    return null;
}
