const std = @import("std");
const Allocator = std.mem.Allocator;
const Writer = std.Io.Writer;
const capture = @import("capture.zig");
const Capture = capture.Capture;
const Scope = @import("scope.zig").Scope;

pub const RenderError = Allocator.Error || capture.ValidationError || Writer.Error;

const scopes = std.enums.values(Scope);
const scope_count = scopes.len;

const Event = struct {
    offset: usize,
    scope: Scope,
    kind: Kind,

    const Kind = enum {
        end,
        start,
    };

    fn lessThan(_: void, left: Event, right: Event) bool {
        if (left.offset != right.offset) return left.offset < right.offset;
        if (left.kind != right.kind) {
            return @backingInt(left.kind) < @backingInt(right.kind);
        }
        return @backingInt(left.scope) < @backingInt(right.scope);
    }
};

/// Writes source as escaped HTML text without adding any markup.
///
/// The function operates on bytes rather than Unicode code points. Invalid
/// UTF-8 is therefore preserved unchanged except for ASCII bytes that require
/// escaping in HTML.
pub fn renderPlain(source: []const u8, writer: *Writer) Writer.Error!void {
    var unescaped_start: usize = 0;

    for (source, 0..) |byte, index| {
        const entity = switch (byte) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&#39;",
            else => continue,
        };

        try writer.writeAll(source[unescaped_start..index]);
        try writer.writeAll(entity);
        unescaped_start = index + 1;
    }

    try writer.writeAll(source[unescaped_start..]);
}

/// Renders source with the supplied syntax captures.
///
/// Captures may be unsorted, duplicated, nested, or crossing. Their boundaries
/// are normalized into disjoint source segments. Each segment receives the set
/// of active scope classes in `Scope` enum order.
pub fn render(
    source: []const u8,
    captures: []const Capture,
    allocator: Allocator,
    writer: *Writer,
) RenderError!void {
    var events: std.ArrayList(Event) = .empty;
    defer events.deinit(allocator);

    // Validate the complete backend result before allocation or output. This
    // gives range errors deterministic precedence over resource failures.
    for (captures) |item| {
        try item.validate(source.len);
    }

    for (captures) |item| {
        if (item.span.isEmpty()) continue;

        try events.append(allocator, .{
            .offset = item.span.start,
            .scope = item.scope,
            .kind = .start,
        });
        try events.append(allocator, .{
            .offset = item.span.end,
            .scope = item.scope,
            .kind = .end,
        });
    }

    if (events.items.len == 0) return renderPlain(source, writer);

    std.sort.insertion(Event, events.items, {}, Event.lessThan);

    var active: [scope_count]usize = @splat(0);
    var cursor: usize = 0;
    var event_index: usize = 0;

    while (event_index < events.items.len) {
        const offset = events.items[event_index].offset;
        if (offset > cursor) {
            try renderSegment(source[cursor..offset], &active, writer);
        }

        while (event_index < events.items.len and
            events.items[event_index].offset == offset) : (event_index += 1)
        {
            const event = events.items[event_index];
            const index = @backingInt(event.scope);
            switch (event.kind) {
                .start => active[index] += 1,
                .end => {
                    std.debug.assert(active[index] > 0);
                    active[index] -= 1;
                },
            }
        }

        cursor = offset;
    }

    try renderSegment(source[cursor..], &active, writer);
    for (active) |count| std.debug.assert(count == 0);
}

fn renderSegment(
    source: []const u8,
    active: *const [scope_count]usize,
    writer: *Writer,
) Writer.Error!void {
    if (source.len == 0) return;

    var has_scope = false;
    for (active) |count| {
        if (count != 0) {
            has_scope = true;
            break;
        }
    }

    if (!has_scope) return renderPlain(source, writer);

    try writer.writeAll("<span class=\"");
    var first = true;
    for (scopes, active) |scope, count| {
        if (count == 0) continue;
        if (!first) try writer.writeByte(' ');
        try writer.writeAll(scope.cssClass());
        first = false;
    }
    try writer.writeAll("\">");
    try renderPlain(source, writer);
    try writer.writeAll("</span>");
}

test "plain renderer escapes HTML-sensitive bytes" {
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain("&<>\"'", &output.writer);
    try std.testing.expectEqualStrings(
        "&amp;&lt;&gt;&quot;&#39;",
        output.written(),
    );
}

test "plain renderer preserves whitespace and ordinary source" {
    const source = "const answer = 42;\n\t// unchanged\n";
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain(source, &output.writer);
    try std.testing.expectEqualStrings(source, output.written());
}

test "plain renderer preserves invalid UTF-8 bytes" {
    const source = [_]u8{ 0xff, '<', 0x80 };
    const expected = [_]u8{ 0xff, '&', 'l', 't', ';', 0x80 };
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain(&source, &output.writer);
    try std.testing.expectEqualSlices(u8, &expected, output.written());
}

test "plain renderer accepts empty input" {
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try renderPlain("", &output.writer);
    try std.testing.expectEqual(@as(usize, 0), output.written().len);
}

test "classified renderer preserves gaps and sorts captures" {
    const source = "const <value>";
    const captures = [_]Capture{
        try .init(7, 12, .variable),
        try .init(0, 5, .keyword),
    };
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try render(source, &captures, std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "<span class=\"syntax-keyword\">const</span> &lt;" ++
            "<span class=\"syntax-variable\">value</span>&gt;",
        output.written(),
    );
}

test "classified renderer normalizes crossing captures" {
    const source = "abcdefgh";
    const captures = [_]Capture{
        try .init(3, 8, .string),
        try .init(0, 5, .comment),
    };
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try render(source, &captures, std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "<span class=\"syntax-comment\">abc</span>" ++
            "<span class=\"syntax-comment syntax-string\">de</span>" ++
            "<span class=\"syntax-string\">fgh</span>",
        output.written(),
    );
}

test "classified renderer deduplicates identical scopes" {
    const source = "u8";
    const captures = [_]Capture{
        try .init(0, 2, .type),
        try .init(0, 2, .builtin),
        try .init(0, 2, .builtin),
    };
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try render(source, &captures, std.testing.allocator, &output.writer);
    try std.testing.expectEqualStrings(
        "<span class=\"syntax-builtin syntax-type\">u8</span>",
        output.written(),
    );
}

test "classified renderer validates every capture" {
    const captures = [_]Capture{.{
        .span = .{ .start = 0, .end = 4 },
        .scope = .string,
    }};
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try std.testing.expectError(
        error.RangeOutOfBounds,
        render("abc", &captures, std.testing.allocator, &output.writer),
    );
    try std.testing.expectEqual(@as(usize, 0), output.written().len);
}

test "capture validation precedes allocation and output" {
    const captures = [_]Capture{
        try .init(0, 2, .keyword),
        .{
            .span = .{ .start = 3, .end = 2 },
            .scope = .invalid,
        },
    };
    var output: Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();

    try std.testing.expectError(
        error.ReversedRange,
        render("abc", &captures, std.testing.failing_allocator, &output.writer),
    );
    try std.testing.expectEqual(@as(usize, 0), output.written().len);
}

test "plain and classified renderers propagate writer failure" {
    var plain_writer: Writer = .failing;
    try std.testing.expectError(
        error.WriteFailed,
        renderPlain("source", &plain_writer),
    );

    const captures = [_]Capture{try .init(0, 6, .string)};
    var classified_writer: Writer = .failing;
    try std.testing.expectError(
        error.WriteFailed,
        render("source", &captures, std.testing.allocator, &classified_writer),
    );
}

fn renderAllocationCase(allocator: Allocator) !void {
    const source = "const value = \"text\";";
    const captures = [_]Capture{
        try .init(0, 5, .keyword),
        try .init(6, 11, .variable),
        try .init(14, 20, .string),
    };
    var discard_buffer: [32]u8 = undefined;
    var discarding: Writer.Discarding = .init(&discard_buffer);

    try render(source, &captures, allocator, &discarding.writer);
}

test "classified renderer handles every allocation failure" {
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        renderAllocationCase,
        .{},
    );
}
