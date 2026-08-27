const std = @import("std");
const syntax = @import("native_syntax");
const conformance = @import("support/backend_conformance.zig");
const backend = syntax.languages.lua.backend;

test "Lua backend metadata is stable" {
    try std.testing.expectEqualStrings("lua", backend.info.canonical_name);
    try std.testing.expectEqual(syntax.BackendKind.parser_backed, backend.info.kind);
    try std.testing.expectEqual(syntax.SupportLevel.verified_structural, backend.info.support_level);
}

test "Lua parser assigns declarations parameters members calls and labels" {
    const source =
        \\local module, count = {}, 2
        \\function module.render(value, options)
        \\  print(options.name)
        \\  goto finished
        \\end
        \\::finished::
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "module", .variable);
    try expectCapture(source, sink.captures(), "count", .variable);
    try expectCapture(source, sink.captures(), "render", .function);
    try expectCapture(source, sink.captures(), "value", .parameter);
    try expectCapture(source, sink.captures(), "options", .parameter);
    try expectCapture(source, sink.captures(), "name", .property);
    try expectCapture(source, sink.captures(), "print", .builtin);
    try expectCapture(source, sink.captures(), "finished", .label);
}

test "Lua parser recognizes balanced long strings comments and escape forms" {
    const source =
        \\local text = [=[first ]] second]=]
        \\--[==[ comment ]=] still comment ]==]
        \\local escaped = "\x41\u{2500}\z   next"
    ;
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "[=[first ]] second]=]", .string);
    try expectCapture(source, sink.captures(), "--[==[ comment ]=] still comment ]==]", .comment);
    try expectCapture(source, sink.captures(), "\\x41", .escape);
    try expectCapture(source, sink.captures(), "\\u{2500}", .escape);
}

test "Lua parser recovers after incomplete constructs" {
    const source = "function broken(first, second\nlocal next_value = call(\n";
    var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
    defer sink.deinit();
    try backend.highlight(source, &sink);

    try expectCapture(source, sink.captures(), "broken", .function);
    try expectCapture(source, sink.captures(), "first", .parameter);
    try expectCapture(source, sink.captures(), "next_value", .variable);
    try expectCapture(source, sink.captures(), "call", .function);
}

test "Lua representative corpora retain structural roles" {
    var found_function = false;
    var found_parameter = false;
    var found_property = false;
    var found_string = false;
    for ([_][]const u8{
        @embedFile("corpus/lua/complete.lua"),
        @embedFile("corpus/lua/module.lua"),
    }) |source| {
        var sink: syntax.CaptureSink = .init(std.testing.allocator, source.len);
        defer sink.deinit();
        try backend.highlight(source, &sink);

        found_function = found_function or hasScope(sink.captures(), .function);
        found_parameter = found_parameter or hasScope(sink.captures(), .parameter);
        found_property = found_property or hasScope(sink.captures(), .property);
        found_string = found_string or hasScope(sink.captures(), .string);
    }
    try std.testing.expect(found_function);
    try std.testing.expect(found_parameter);
    try std.testing.expect(found_property);
    try std.testing.expect(found_string);
}

test "Lua parser conforms to the shared backend contract" {
    const invalid_utf8 = [_]u8{ 'l', 'o', 'c', 'a', 'l', ' ', 0xff, ' ', '=', ' ', '1' };
    try conformance.expectConforms(backend, .{
        .valid = .{
            .source = @embedFile("corpus/lua/complete.lua"),
            .required_scopes = &.{ .keyword, .function, .parameter, .variable, .string, .escape, .boolean, .number, .comment, .operator, .punctuation },
        },
        .malformed = .{
            .source = "function broken(value\nlocal text = \"unterminated\\n<&>\n",
            .required_scopes = &.{ .keyword, .function, .parameter, .string, .escape },
        },
        .multiline = .{
            .source = "local text = [=[first\nsecond <&>]=]\n-- done\n",
            .required_scopes = &.{ .variable, .string, .comment },
        },
        .escapable = .{
            .source = "local value = \"<&>\\\"'\" -- comment",
            .required_scopes = &.{ .variable, .string, .escape, .comment },
        },
        .invalid_utf8 = .{
            .source = &invalid_utf8,
            .required_scopes = &.{ .keyword, .number, .operator },
        },
    });
}

fn expectCapture(source: []const u8, captures: []const syntax.Capture, text: []const u8, scope: syntax.Scope) !void {
    for (captures) |capture| {
        if (capture.scope == scope and std.mem.eql(u8, try capture.span.slice(source), text)) return;
    }
    return error.TestExpectedEqual;
}

fn hasScope(captures: []const syntax.Capture, expected: syntax.Scope) bool {
    for (captures) |capture| if (capture.scope == expected) return true;
    return false;
}
