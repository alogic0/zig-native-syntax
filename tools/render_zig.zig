const std = @import("std");
const syntax = @import("native_syntax");

const Options = struct {
    path: []const u8,
    page: bool,
};

const Command = union(enum) {
    help,
    render: Options,
};

const ArgumentError = error{
    MissingPath,
    MultiplePaths,
    UnknownOption,
};

const page_header =
    \\<!doctype html>
    \\<html lang="en">
    \\<head>
    \\<meta charset="utf-8">
    \\<meta name="viewport" content="width=device-width, initial-scale=1">
    \\<title>Zig syntax preview</title>
    \\<style>
    \\:root { color-scheme: dark; }
    \\body { margin: 0; background: #111827; color: #d1d5db; font-family: ui-monospace, monospace; }
    \\main { padding: 2rem; }
    \\pre { margin: 0; padding: 1.25rem; overflow: auto; border: 1px solid #374151; border-radius: .5rem; background: #0b1020; line-height: 1.5; tab-size: 4; }
    \\.syntax-comment, .syntax-documentation { color: #6b7280; font-style: italic; }
    \\.syntax-keyword { color: #c084fc; }
    \\.syntax-builtin, .syntax-type { color: #67e8f9; }
    \\.syntax-function { color: #fde68a; }
    \\.syntax-parameter { color: #fdba74; }
    \\.syntax-property { color: #93c5fd; }
    \\.syntax-string { color: #86efac; }
    \\.syntax-escape { color: #f0abfc; font-weight: 600; }
    \\.syntax-number, .syntax-boolean, .syntax-constant { color: #fca5a5; }
    \\.syntax-operator, .syntax-punctuation { color: #9ca3af; }
    \\.syntax-invalid { color: #f87171; text-decoration: underline wavy; }
    \\</style>
    \\</head>
    \\<body><main><pre><code class="language-zig">
;

const page_footer = "</code></pre></main></body>\n</html>\n";

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const command = parseArgs(args[1..]) catch |err| {
        var stderr_buffer: [1024]u8 = undefined;
        var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
        const stderr = &stderr_writer.interface;
        try stderr.print("render-zig: {s}\n\n", .{argumentErrorMessage(err)});
        try writeUsage(stderr);
        try stderr.flush();
        std.process.exit(2);
    };

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    switch (command) {
        .help => {
            try writeUsage(stdout);
            try stdout.flush();
        },
        .render => |options| {
            const source = std.Io.Dir.cwd().readFileAlloc(
                init.io,
                options.path,
                init.gpa,
                .limited(std.math.maxInt(u32)),
            ) catch |err| {
                var stderr_buffer: [1024]u8 = undefined;
                var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
                const stderr = &stderr_writer.interface;
                try stderr.print(
                    "render-zig: cannot read '{s}': {s}\n",
                    .{ options.path, @errorName(err) },
                );
                try stderr.flush();
                std.process.exit(1);
            };
            defer init.gpa.free(source);

            try renderSource(source, options.page, init.gpa, stdout);
            try stdout.flush();
        },
    }
}

fn parseArgs(args: []const [:0]const u8) ArgumentError!Command {
    var path: ?[]const u8 = null;
    var page = false;
    var positional_only = false;

    for (args) |sentinel_arg| {
        const arg: []const u8 = sentinel_arg;

        if (!positional_only and std.mem.eql(u8, arg, "--")) {
            positional_only = true;
        } else if (!positional_only and
            (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")))
        {
            return .help;
        } else if (!positional_only and std.mem.eql(u8, arg, "--page")) {
            page = true;
        } else if (!positional_only and std.mem.startsWith(u8, arg, "-")) {
            return error.UnknownOption;
        } else if (path != null) {
            return error.MultiplePaths;
        } else {
            path = arg;
        }
    }

    return .{ .render = .{
        .path = path orelse return error.MissingPath,
        .page = page,
    } };
}

fn argumentErrorMessage(err: ArgumentError) []const u8 {
    return switch (err) {
        error.MissingPath => "missing Zig source path",
        error.MultiplePaths => "expected exactly one Zig source path",
        error.UnknownOption => "unknown option",
    };
}

fn writeUsage(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.writeAll(
        \\Usage: ./build.sh render-zig [--page] <source.zig>
        \\
        \\Render Zig source as safely escaped highlighted HTML.
        \\
        \\Options:
        \\  --page    Emit a complete HTML document with a development theme.
        \\  -h, --help
        \\            Show this help text.
        \\
    );
}

fn renderSource(
    source: []const u8,
    page: bool,
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
) !void {
    var sink: syntax.CaptureSink = .init(allocator, source.len);
    defer sink.deinit();
    try syntax.languages.zig.backend.highlight(source, &sink);

    if (page) try writer.writeAll(page_header);
    try syntax.html.render(source, sink.captures(), allocator, writer);
    if (page) try writer.writeAll(page_footer);
}

test "arguments select fragment and page output" {
    const fragment = try parseArgs(&.{"sample.zig"});
    try std.testing.expectEqualStrings("sample.zig", fragment.render.path);
    try std.testing.expect(!fragment.render.page);

    const page = try parseArgs(&.{ "sample.zig", "--page" });
    try std.testing.expectEqualStrings("sample.zig", page.render.path);
    try std.testing.expect(page.render.page);

    const dash_path = try parseArgs(&.{ "--", "--page" });
    try std.testing.expectEqualStrings("--page", dash_path.render.path);
    try std.testing.expect(!dash_path.render.page);
}

test "arguments report invalid invocations" {
    try std.testing.expectError(error.MissingPath, parseArgs(&.{}));
    try std.testing.expectError(error.UnknownOption, parseArgs(&.{"--unknown"}));
    try std.testing.expectError(error.MultiplePaths, parseArgs(&.{ "one.zig", "two.zig" }));
    try std.testing.expectEqual(Command.help, try parseArgs(&.{"--help"}));
}

test "fragment output contains only highlighted source" {
    const source = "const value: u8 = 42;";
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderSource(source, false, std.testing.allocator, &output.writer);

    try std.testing.expect(!std.mem.startsWith(u8, output.written(), "<!doctype html>"));
    try std.testing.expect(std.mem.startsWith(
        u8,
        output.written(),
        "<span class=\"syntax-keyword\">const</span>",
    ));
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<pre>") == null);
}

test "page output is complete, themed, and source safe" {
    const source = "const text = \"</code><script>alert('x')</script>\";";
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderSource(source, true, std.testing.allocator, &output.writer);

    try std.testing.expect(std.mem.startsWith(u8, output.written(), "<!doctype html>\n"));
    try std.testing.expect(std.mem.indexOf(u8, output.written(), ".syntax-keyword") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<script>") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "&lt;/code&gt;") != null);
    try std.testing.expect(std.mem.endsWith(u8, output.written(), "</html>\n"));
}
