//! Shared lossless storage and cursor primitives for language-specific parsers.
//!
//! The source is externally owned. Trees own only their token, node, and
//! diagnostic storage, and every location is a byte offset into that source.

const std = @import("std");

pub const ByteOffset = u32;
pub const TokenIndex = u32;
pub const NodeIndex = u32;

pub const BuildError = error{
    SourceTooLarge,
    InvalidByteRange,
    InvalidTokenRange,
} || std.mem.Allocator.Error;

/// Instantiates syntax storage for one language's token, node, and diagnostic
/// tag enums. Grammar and recovery behavior intentionally remain outside this
/// type.
pub fn Model(
    comptime TokenTag: type,
    comptime NodeTag: type,
    comptime DiagnosticTag: type,
) type {
    return struct {
        const ModelType = @This();

        pub const Token = struct {
            tag: TokenTag,
            start: ByteOffset,
            end: ByteOffset,

            pub fn slice(token: Token, source: []const u8) []const u8 {
                return source[token.start..token.end];
            }
        };

        pub const Node = struct {
            tag: NodeTag,
            first_token: TokenIndex,
            last_token: TokenIndex,
            main_token: TokenIndex,
        };

        pub const Diagnostic = struct {
            tag: DiagnosticTag,
            offset: ByteOffset,
        };

        pub const Tree = struct {
            source: []const u8,
            tokens: []Token,
            nodes: []Node,
            diagnostics: []Diagnostic,

            pub fn deinit(tree: *Tree, allocator: std.mem.Allocator) void {
                allocator.free(tree.tokens);
                allocator.free(tree.nodes);
                allocator.free(tree.diagnostics);
                tree.* = undefined;
            }

            pub fn tokenSlice(tree: Tree, token_index: TokenIndex) []const u8 {
                return tree.tokens[token_index].slice(tree.source);
            }
        };

        pub const Builder = struct {
            allocator: std.mem.Allocator,
            source_len: ByteOffset,
            tokens: std.ArrayList(Token) = .empty,
            nodes: std.ArrayList(Node) = .empty,
            diagnostics: std.ArrayList(Diagnostic) = .empty,

            pub fn init(allocator: std.mem.Allocator, source_len: usize) BuildError!Builder {
                if (source_len > std.math.maxInt(ByteOffset)) return error.SourceTooLarge;
                return .{
                    .allocator = allocator,
                    .source_len = @intCast(source_len),
                };
            }

            pub fn deinit(builder: *Builder) void {
                builder.tokens.deinit(builder.allocator);
                builder.nodes.deinit(builder.allocator);
                builder.diagnostics.deinit(builder.allocator);
                builder.* = undefined;
            }

            pub fn addToken(
                builder: *Builder,
                tag: TokenTag,
                start: usize,
                end: usize,
            ) BuildError!TokenIndex {
                if (start > end or end > builder.source_len) return error.InvalidByteRange;
                if (builder.tokens.items.len >= std.math.maxInt(TokenIndex)) return error.SourceTooLarge;

                const token_index: TokenIndex = @intCast(builder.tokens.items.len);
                try builder.tokens.append(builder.allocator, .{
                    .tag = tag,
                    .start = @intCast(start),
                    .end = @intCast(end),
                });
                return token_index;
            }

            pub fn addNode(
                builder: *Builder,
                tag: NodeTag,
                first_token: TokenIndex,
                last_token: TokenIndex,
                main_token: TokenIndex,
            ) BuildError!NodeIndex {
                const token_count = builder.tokens.items.len;
                if (first_token > last_token or last_token > token_count or main_token >= token_count) {
                    return error.InvalidTokenRange;
                }
                if (main_token < first_token or main_token >= last_token) return error.InvalidTokenRange;
                if (builder.nodes.items.len >= std.math.maxInt(NodeIndex)) return error.SourceTooLarge;

                const node_index: NodeIndex = @intCast(builder.nodes.items.len);
                try builder.nodes.append(builder.allocator, .{
                    .tag = tag,
                    .first_token = first_token,
                    .last_token = last_token,
                    .main_token = main_token,
                });
                return node_index;
            }

            pub fn addDiagnostic(
                builder: *Builder,
                tag: DiagnosticTag,
                offset: usize,
            ) BuildError!void {
                if (offset > builder.source_len) return error.InvalidByteRange;
                try builder.diagnostics.append(builder.allocator, .{
                    .tag = tag,
                    .offset = @intCast(offset),
                });
            }

            /// Transfers all accumulated storage to a tree. The builder remains
            /// valid and empty so both success and failure paths have one clear
            /// owner for every allocation.
            pub fn finish(builder: *Builder, source: []const u8) BuildError!Tree {
                if (source.len != builder.source_len) return error.InvalidByteRange;

                const tokens = try builder.tokens.toOwnedSlice(builder.allocator);
                errdefer builder.allocator.free(tokens);
                const nodes = try builder.nodes.toOwnedSlice(builder.allocator);
                errdefer builder.allocator.free(nodes);
                const diagnostics = try builder.diagnostics.toOwnedSlice(builder.allocator);

                return .{
                    .source = source,
                    .tokens = tokens,
                    .nodes = nodes,
                    .diagnostics = diagnostics,
                };
            }
        };

        pub const Cursor = struct {
            tokens: []const Token,
            index: usize = 0,

            pub fn init(tokens: []const Token) Cursor {
                return .{ .tokens = tokens };
            }

            pub fn atEnd(cursor: Cursor) bool {
                return cursor.index >= cursor.tokens.len;
            }

            pub fn peek(cursor: Cursor, lookahead: usize) ?Token {
                const index = std.math.add(usize, cursor.index, lookahead) catch return null;
                if (index >= cursor.tokens.len) return null;
                return cursor.tokens[index];
            }

            pub fn peekTag(cursor: Cursor, lookahead: usize) ?TokenTag {
                return if (cursor.peek(lookahead)) |token| token.tag else null;
            }

            pub fn advance(cursor: *Cursor) ?TokenIndex {
                if (cursor.atEnd()) return null;
                const token_index: TokenIndex = @intCast(cursor.index);
                cursor.index += 1;
                return token_index;
            }

            pub fn eat(cursor: *Cursor, tag: TokenTag) ?TokenIndex {
                if (cursor.peekTag(0) != tag) return null;
                return cursor.advance();
            }

            /// Advances until the current token has one of the supplied tags.
            /// The synchronization token itself is left unconsumed.
            pub fn synchronize(cursor: *Cursor, tags: []const TokenTag) usize {
                const start = cursor.index;
                while (cursor.peekTag(0)) |tag| {
                    if (std.mem.indexOfScalar(TokenTag, tags, tag) != null) break;
                    cursor.index += 1;
                }
                return cursor.index - start;
            }
        };

        comptime {
            _ = ModelType;
        }
    };
}

test "syntax model transfers lossless token and node storage" {
    const TokenTag = enum { keyword, identifier, equal, number };
    const NodeTag = enum { variable_declaration };
    const DiagnosticTag = enum { expected_identifier };
    const Syntax = Model(TokenTag, NodeTag, DiagnosticTag);
    const source = "const answer = 42";

    var builder = try Syntax.Builder.init(std.testing.allocator, source.len);
    defer builder.deinit();

    _ = try builder.addToken(.keyword, 0, 5);
    _ = try builder.addToken(.identifier, 6, 12);
    _ = try builder.addToken(.equal, 13, 14);
    _ = try builder.addToken(.number, 15, 17);
    _ = try builder.addNode(.variable_declaration, 0, 4, 1);

    var tree = try builder.finish(source);
    defer tree.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("answer", tree.tokenSlice(1));
    try std.testing.expectEqual(NodeTag.variable_declaration, tree.nodes[0].tag);
    try std.testing.expectEqual(@as(usize, 0), tree.diagnostics.len);
}

test "syntax cursor bounds lookahead and synchronizes for recovery" {
    const TokenTag = enum { identifier, comma, semicolon };
    const NodeTag = enum { root };
    const DiagnosticTag = enum { expected_separator };
    const Syntax = Model(TokenTag, NodeTag, DiagnosticTag);
    const tokens = [_]Syntax.Token{
        .{ .tag = .identifier, .start = 0, .end = 1 },
        .{ .tag = .identifier, .start = 2, .end = 3 },
        .{ .tag = .semicolon, .start = 3, .end = 4 },
    };

    var cursor = Syntax.Cursor.init(&tokens);
    try std.testing.expectEqual(TokenTag.identifier, cursor.peekTag(0).?);
    try std.testing.expectEqual(@as(usize, 2), cursor.synchronize(&.{.semicolon}));
    try std.testing.expectEqual(TokenTag.semicolon, cursor.peekTag(0).?);
    try std.testing.expectEqual(@as(TokenIndex, 2), cursor.eat(.semicolon).?);
    try std.testing.expect(cursor.atEnd());
    try std.testing.expectEqual(@as(?TokenTag, null), cursor.peekTag(std.math.maxInt(usize)));
}

test "syntax builder rejects invalid source and token ranges" {
    const TokenTag = enum { identifier };
    const NodeTag = enum { root };
    const DiagnosticTag = enum { expected_identifier };
    const Syntax = Model(TokenTag, NodeTag, DiagnosticTag);

    var builder = try Syntax.Builder.init(std.testing.allocator, 3);
    defer builder.deinit();

    try std.testing.expectError(error.InvalidByteRange, builder.addToken(.identifier, 2, 4));
    _ = try builder.addToken(.identifier, 0, 3);
    try std.testing.expectError(error.InvalidTokenRange, builder.addNode(.root, 0, 1, 1));
    try std.testing.expectError(error.InvalidByteRange, builder.addDiagnostic(.expected_identifier, 4));
}
