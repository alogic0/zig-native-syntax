const api = @import("../backend.zig");
const g = @import("generic.zig");

const keywords = &.{ "allocate", "allocatable", "associate", "block", "call", "case", "class", "contains", "cycle", "data", "deallocate", "dimension", "do", "else", "elseif", "elsewhere", "end", "entry", "enum", "equivalence", "exit", "extends", "external", "forall", "format", "function", "generic", "go", "goto", "if", "implicit", "import", "in", "include", "intent", "interface", "intrinsic", "module", "namelist", "none", "only", "operator", "optional", "parameter", "pointer", "private", "procedure", "program", "protected", "public", "pure", "read", "recursive", "result", "return", "save", "select", "sequence", "stop", "submodule", "subroutine", "target", "then", "type", "use", "value", "volatile", "where", "while", "write" };
const types = &.{ "character", "complex", "double", "integer", "logical", "precision", "real" };

pub const backend: api.Backend = .init(.{ .canonical_name = "fortran", .display_name = "Fortran", .kind = .lexical, .support_level = .verified_lexical }, highlight);

fn highlight(source: []const u8, sink: *api.CaptureSink) api.HighlightError!void {
    try g.highlight(source, sink, .{ .line_comments = &.{"!"}, .keywords = keywords, .types = types, .case_insensitive = true });
}
