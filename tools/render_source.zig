const std = @import("std");
const syntax = @import("native_syntax");
const preview_backend = @import("preview_backend");
const preview_config = @import("preview_config");

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

const page_css = @embedFile("render_zig.css");

const page_header =
    "<!doctype html>\n" ++
    "<html lang=\"en\">\n" ++
    "<head>\n" ++
    "<meta charset=\"utf-8\">\n" ++
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n";

const page_code_header =
    "</style>\n" ++
    "</head>\n" ++
    "<body><main><pre><code";

const page_footer = "</code></pre></main></body>\n</html>\n";

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const command = parseArgs(args[1..]) catch |err| {
        var stderr_buffer: [1024]u8 = undefined;
        var stderr_writer = std.Io.File.stderr().writer(init.io, &stderr_buffer);
        const stderr = &stderr_writer.interface;
        try stderr.print("{s}: {s}\n\n", .{
            preview_config.command_name,
            argumentErrorMessage(err),
        });
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
                    "{s}: cannot read '{s}': {s}\n",
                    .{ preview_config.command_name, options.path, @errorName(err) },
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
        error.MissingPath => "missing source path",
        error.MultiplePaths => "expected exactly one source path",
        error.UnknownOption => "unknown option",
    };
}

fn writeUsage(writer: *std.Io.Writer) std.Io.Writer.Error!void {
    try writer.print(
        \\Usage: ./build.sh {s} [--page] <{s}>
        \\
        \\Render {s} source as safely escaped highlighted HTML.
        \\
        \\Options:
        \\  --page    Emit a complete HTML document with a development theme.
        \\  -h, --help
        \\            Show this help text.
        \\
    , .{
        preview_config.command_name,
        preview_config.sample_path,
        preview_config.display_name,
    });
}

fn renderSource(
    source: []const u8,
    page: bool,
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
) !void {
    var sink: syntax.CaptureSink = .init(allocator, source.len);
    defer sink.deinit();
    try preview_backend.backend.highlight(source, &sink);

    if (page) {
        try writer.writeAll(page_header);
        try writer.print("<title>{s} syntax preview</title>\n", .{preview_config.display_name});
        try writer.writeAll("<style>\n");
        try writer.writeAll(page_css);
        try writer.writeAll(page_code_header);
        try writer.print(" class=\"{s}\">", .{preview_config.language_class});
    }
    try syntax.html.render(source, sink.captures(), allocator, writer);
    if (page) try writer.writeAll(page_footer);
}

test "arguments select fragment and page output" {
    const fragment = try parseArgs(&.{"sample.source"});
    try std.testing.expectEqualStrings("sample.source", fragment.render.path);
    try std.testing.expect(!fragment.render.page);

    const page = try parseArgs(&.{ "sample.source", "--page" });
    try std.testing.expectEqualStrings("sample.source", page.render.path);
    try std.testing.expect(page.render.page);

    const dash_path = try parseArgs(&.{ "--", "--page" });
    try std.testing.expectEqualStrings("--page", dash_path.render.path);
    try std.testing.expect(!dash_path.render.page);
}

test "arguments report invalid invocations" {
    try std.testing.expectError(error.MissingPath, parseArgs(&.{}));
    try std.testing.expectError(error.UnknownOption, parseArgs(&.{"--unknown"}));
    try std.testing.expectError(error.MultiplePaths, parseArgs(&.{ "one", "two" }));
    try std.testing.expectEqual(Command.help, try parseArgs(&.{"--help"}));
}

test "fragment output contains only safely escaped source" {
    const source = "<tag title=\"x\">&'";
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderSource(source, false, std.testing.allocator, &output.writer);

    try std.testing.expect(!std.mem.startsWith(u8, output.written(), "<!doctype html>"));
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<tag") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "&lt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "&amp;") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<pre>") == null);
}

test "page output is complete, themed, and source safe" {
    const source = "</code><script>alert('x')</script>";
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderSource(source, true, std.testing.allocator, &output.writer);

    try std.testing.expect(std.mem.startsWith(u8, output.written(), "<!doctype html>\n"));
    try std.testing.expect(std.mem.indexOf(u8, output.written(), ".syntax-keyword") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "<script>") == null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), "&lt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, output.written(), preview_config.language_class) != null);
    try std.testing.expect(std.mem.endsWith(u8, output.written(), "</html>\n"));
}
