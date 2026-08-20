const std = @import("std");
const core = @import("native_syntax");
const html = @import("superhtml_html");

pub fn highlight(
    source: []const u8,
    language: html.Language,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    if (source.len > std.math.maxInt(u32)) return;

    var tokenizer: html.Tokenizer = .{
        .language = language,
        .return_attrs = true,
    };
    var pending_raw_element: ?RawElement = null;
    var inside_raw_element = false;

    while (tokenizer.next(source)) |token| {
        switch (token) {
            .tag_name => |span| {
                try addSpan(span, .tag, sink);
                try classifyTagDelimiters(source, span, sink);

                if (inside_raw_element) {
                    inside_raw_element = false;
                } else if (language != .xml and isStartTag(source, span)) {
                    if (rawElement(span.slice(source))) |raw_element| {
                        switch (nextTagByte(source, span.end)) {
                            '>' => {
                                enterRawElement(&tokenizer, raw_element);
                                inside_raw_element = true;
                            },
                            '/' => {},
                            else => pending_raw_element = raw_element,
                        }
                    }
                }
            },
            .attr => |attribute| try classifyAttribute(source, attribute, sink),
            .doctype => |doctype| try addSpan(doctype.span, .keyword, sink),
            .comment => |span| try addSpan(
                span,
                if (language == .xml and std.mem.startsWith(u8, span.slice(source), "<?"))
                    .special
                else
                    .comment,
                sink,
            ),
            .text => |span| {
                if (!inside_raw_element) {
                    try classifyEntities(source, span.start, span.end, sink);
                }
            },
            .parse_error => |parse_error| {
                if (!inside_raw_element) try addSpan(parse_error.span, .invalid, sink);
            },
            .tag => |tag| {
                if (inside_raw_element) {
                    try addSpan(tag.name, .tag, sink);
                    try classifyTagDelimiters(source, tag.name, sink);
                    inside_raw_element = false;
                } else if (pending_raw_element) |raw_element| {
                    pending_raw_element = null;
                    if (tag.kind == .start) {
                        enterRawElement(&tokenizer, raw_element);
                        inside_raw_element = true;
                    }
                }
            },
        }
    }
}

const RawElement = enum { script, style };

fn rawElement(name: []const u8) ?RawElement {
    if (std.ascii.eqlIgnoreCase(name, "script")) return .script;
    if (std.ascii.eqlIgnoreCase(name, "style")) return .style;
    return null;
}

fn isStartTag(source: []const u8, name: html.Span) bool {
    return name.start > 0 and source[name.start - 1] == '<';
}

fn nextTagByte(source: []const u8, start: u32) u8 {
    var index: usize = start;
    while (index < source.len and std.ascii.isWhitespace(source[index])) index += 1;
    return if (index < source.len) source[index] else 0;
}

fn enterRawElement(tokenizer: *html.Tokenizer, raw_element: RawElement) void {
    switch (raw_element) {
        .script => tokenizer.gotoScriptData(),
        .style => tokenizer.gotoRawText("style"),
    }
}

fn classifyAttribute(
    source: []const u8,
    attribute: html.Tokenizer.Attr,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    try addSpan(attribute.name, .attribute, sink);

    const value = attribute.value orelse return;
    const value_start: usize = value.span.start;
    const value_end: usize = value.span.end;
    const string_start = switch (value.quote) {
        .none => value_start,
        .single, .double => value_start -| 1,
    };
    const string_end = switch (value.quote) {
        .none => value_end,
        .single, .double => @min(value_end + 1, source.len),
    };

    try sink.add(string_start, string_end, .string);
    try classifyEntities(source, value_start, value_end, sink);

    const between_end = string_start;
    var index: usize = attribute.name.end;
    while (index < between_end) : (index += 1) {
        if (source[index] == '=') {
            try sink.add(index, index + 1, .operator);
            break;
        }
    }
}

fn classifyTagDelimiters(
    source: []const u8,
    name: html.Span,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    const name_start: usize = name.start;
    const name_end: usize = name.end;

    if (name_start > 0 and source[name_start - 1] == '<') {
        try sink.add(name_start - 1, name_start, .punctuation);
    } else if (name_start > 1 and source[name_start - 1] == '/' and source[name_start - 2] == '<') {
        try sink.add(name_start - 2, name_start - 1, .punctuation);
        try sink.add(name_start - 1, name_start, .punctuation);
    }

    var quote: ?u8 = null;
    var index = name_end;
    while (index < source.len) : (index += 1) {
        const byte = source[index];
        if (quote) |active_quote| {
            if (byte == active_quote) quote = null;
            continue;
        }
        if (byte == '\'' or byte == '"') {
            quote = byte;
            continue;
        }
        if (byte == '>') {
            if (index > name_end and source[index - 1] == '/') {
                try sink.add(index - 1, index, .punctuation);
            }
            try sink.add(index, index + 1, .punctuation);
            return;
        }
        if (byte == '<') return;
    }
}

fn classifyEntities(
    source: []const u8,
    start: usize,
    end: usize,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    var index: usize = start;
    const limit: usize = end;
    while (index < limit) {
        if (source[index] != '&') {
            index += 1;
            continue;
        }

        const entity_start = index;
        index += 1;
        if (index < limit and source[index] == '#') {
            index += 1;
            if (index < limit and (source[index] == 'x' or source[index] == 'X')) index += 1;
        }

        const body_start = index;
        while (index < limit and std.ascii.isAlphanumeric(source[index])) index += 1;
        if (index > body_start and index < limit and source[index] == ';') {
            index += 1;
            try sink.add(entity_start, index, .escape);
        }
    }
}

fn addSpan(
    span: html.Span,
    scope: core.Scope,
    sink: *core.CaptureSink,
) core.HighlightError!void {
    try sink.add(span.start, span.end, scope);
}
