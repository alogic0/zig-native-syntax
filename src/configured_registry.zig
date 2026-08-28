const std = @import("std");
const syntax = @import("native_syntax");
const options = @import("registry_options");

const ziggy = if (options.ziggy) @import("native_syntax_ziggy") else struct {};
const ziggy_schema = if (options.ziggy_schema) @import("native_syntax_ziggy_schema") else struct {};
const scripty = if (options.scripty) @import("native_syntax_scripty") else struct {};
const html = if (options.html) @import("native_syntax_html") else struct {};
const xml = if (options.xml) @import("native_syntax_xml") else struct {};
const css = if (options.css) @import("native_syntax_css") else struct {};
const superhtml = if (options.superhtml) @import("native_syntax_superhtml") else struct {};
const markdown = if (options.markdown) @import("native_syntax_markdown") else struct {};
const core_backends = syntax.collectBackendsForAnalysis(
    syntax.languages,
    options.size_analysis_inclusions,
    options.size_analysis_exclusions,
);

const external_count: usize = @intFromBool(options.ziggy) +
    @as(usize, @intFromBool(options.ziggy_schema)) +
    @as(usize, @intFromBool(options.scripty)) +
    @as(usize, @intFromBool(options.html)) +
    @as(usize, @intFromBool(options.xml)) +
    @as(usize, @intFromBool(options.css)) +
    @as(usize, @intFromBool(options.superhtml)) +
    @as(usize, @intFromBool(options.markdown));

/// All verified core backends plus every verified external backend enabled by
/// the dependency's build options. Analysis builds may additionally link an
/// explicit set of experimental core backends without promoting them.
pub const backends = blk: {
    var result: [core_backends.len + external_count]syntax.Backend = undefined;
    var index: usize = 0;
    for (core_backends) |backend| {
        result[index] = backend;
        index += 1;
    }
    if (options.ziggy) append(&result, &index, ziggy.backend);
    if (options.ziggy_schema) append(&result, &index, ziggy_schema.backend);
    if (options.scripty) append(&result, &index, scripty.backend);
    if (options.html) append(&result, &index, html.backend);
    if (options.xml) append(&result, &index, xml.backend);
    if (options.css) append(&result, &index, css.backend);
    if (options.superhtml) append(&result, &index, superhtml.backend);
    if (options.markdown) append(&result, &index, markdown.backend);
    break :blk result;
};

pub fn backendForName(name: []const u8) ?syntax.Backend {
    const canonical = syntax.canonicalLanguageName(name);
    for (backends) |backend| {
        if (std.ascii.eqlIgnoreCase(canonical, backend.info.canonical_name)) return backend;
    }
    return null;
}

pub const analysis_mode = options.size_analysis_inclusions.len != 0;

fn append(
    result: anytype,
    index: *usize,
    backend: syntax.Backend,
) void {
    result[index.*] = backend;
    index.* += 1;
}
