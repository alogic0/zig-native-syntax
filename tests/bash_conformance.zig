const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");

const backend = syntax.languages.bash.backend;

test "Bash backend metadata is stable" {
    try std.testing.expectEqualStrings("bash", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.lexical, backend.info.kind);
}

test "Bash scanner conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'i', 'f', ' ', 0xff, ';', ' ', 'f', 'i' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source =
            \\#!/usr/bin/env bash
            \\value=42
            \\if [[ -n "$HOME" ]]; then
            \\    printf "line\\n"
            \\    printf '%s\\n' "$(pwd)" $((40 + 2))
            \\fi # complete
            ,
            .required_scopes = &.{ .comment, .keyword, .string, .escape, .variable, .embedded, .operator, .number },
        },
        .malformed = .{
            .source = "if true; then\necho \"$HOME $(date\n",
            .required_scopes = &.{ .keyword, .string, .variable, .embedded, .operator },
        },
        .multiline = .{
            .source = "cat <<'EOF'\n<&body>\nEOF\necho done\n",
            .required_scopes = &.{ .operator, .label, .string },
        },
        .escapable = .{
            .source = "printf \"%s\" '<tag>&\"'\n",
            .required_scopes = &.{.string},
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .operator },
        },
        .extra_cases = &.{.{
            .source = "cat <<EOF\nbody\n",
            .required_scopes = &.{ .operator, .label, .string },
        }},
    });
}

test "Bash classifications retain source ranges" {
    const source = "for item in 1 2; do echo ${item}; done\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "for", .keyword);
    try expectCapture(source, sink.captures(), "in", .keyword);
    try expectCapture(source, sink.captures(), "1", .number);
    try expectCapture(source, sink.captures(), ";", .operator);
    try expectCapture(source, sink.captures(), "${item}", .variable);
}

test "Bash corpus covers heredocs and incomplete constructs" {
    const source = @embedFile("corpus/bash/complete.sh");
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "#!/usr/bin/env bash", .comment);
    try expectCapture(source, sink.captures(), "${name:-world}", .variable);
    try expectCapture(source, sink.captures(), "$(printf '%s' \"$name\")", .embedded);
    try expectCapture(source, sink.captures(), "EOF", .label);
}

fn expectCapture(
    source: []const u8,
    captures: []const syntax.Capture,
    text: []const u8,
    scope: syntax.Scope,
) !void {
    for (captures) |capture| {
        if (capture.scope == scope and
            std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}
