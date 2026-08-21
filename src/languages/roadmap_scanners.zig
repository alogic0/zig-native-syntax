const api = @import("../backend.zig");
const generic = @import("generic.zig");

pub const Kind = enum { kdl, nix, fish, nu, awk, ssh_config, gitcommit, git_rebase, po, rst, latex, typst, org, dtd, mail, hurl, ninja, rpmspec, gdscript, perl, elixir, fsharp, ocaml, haskell, gleam, commonlisp, scheme, julia, elm, purescript, nim };

pub fn highlight(source: []const u8, sink: *api.CaptureSink, kind: Kind) api.HighlightError!void {
    try generic.highlight(source, sink, config(kind));
}

fn config(kind: Kind) generic.Config {
    return switch (kind) {
        .kdl => .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .types = &.{ "i64", "f64", "string", "bool" } },
        .nix => .{ .line_comments = &.{"#"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "assert", "else", "if", "in", "inherit", "let", "or", "rec", "then", "with" } },
        .fish => .{ .line_comments = &.{"#"}, .keywords = &.{ "and", "begin", "break", "case", "else", "end", "for", "function", "if", "in", "not", "or", "return", "set", "switch", "while" } },
        .nu => .{ .line_comments = &.{"#"}, .keywords = &.{ "alias", "break", "const", "def", "else", "export", "extern", "for", "if", "in", "let", "match", "module", "mut", "return", "use", "while" }, .types = &.{ "bool", "float", "int", "list", "nothing", "record", "string", "table" } },
        .awk => .{ .line_comments = &.{"#"}, .keywords = &.{ "BEGIN", "END", "break", "continue", "delete", "else", "exit", "for", "function", "getline", "if", "in", "next", "print", "printf", "return", "while" } },
        .ssh_config => .{ .line_comments = &.{"#"}, .keywords = &.{ "Host", "Match", "HostName", "IdentityFile", "Include", "Port", "ProxyJump", "SendEnv", "SetEnv", "User" }, .case_insensitive = true },
        .gitcommit => .{ .line_comments = &.{"#"} },
        .git_rebase => .{ .line_comments = &.{"#"}, .keywords = &.{ "break", "drop", "edit", "exec", "fixup", "label", "merge", "pick", "reword", "reset", "squash", "update-ref" } },
        .po => .{ .line_comments = &.{"#"}, .keywords = &.{ "msgctxt", "msgid", "msgid_plural", "msgstr" } },
        .rst => .{ .line_comments = &.{".. "}, .keywords = &.{ "attention", "code-block", "contents", "image", "include", "note", "raw", "reference", "tip", "warning" } },
        .latex => .{ .line_comments = &.{"%"}, .keywords = &.{ "begin", "chapter", "cite", "documentclass", "emph", "end", "include", "input", "item", "label", "ref", "section", "subsection", "textbf", "usepackage" } },
        .typst => .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "/*", .close = "*/" }}, .keywords = &.{ "and", "as", "break", "context", "else", "for", "if", "import", "in", "include", "let", "none", "not", "or", "return", "set", "show", "while" }, .types = &.{ "array", "bool", "content", "dictionary", "float", "function", "int", "str" } },
        .org => .{ .line_comments = &.{"# "}, .keywords = &.{ "BEGIN_SRC", "END_SRC", "TODO", "DONE", "PROPERTIES", "END" } },
        .dtd => .{ .line_comments = &.{"<!--"}, .keywords = &.{ "ATTLIST", "DOCTYPE", "ELEMENT", "ENTITY", "NOTATION", "PUBLIC", "SYSTEM" }, .types = &.{ "ANY", "CDATA", "EMPTY", "ID", "IDREF", "NMTOKEN", "PCDATA" } },
        .mail => .{ .line_comments = &.{">"}, .keywords = &.{ "From", "To", "Cc", "Date", "Subject", "Reply-To", "Message-ID", "Content-Type" }, .case_insensitive = true },
        .hurl => .{ .line_comments = &.{"#"}, .keywords = &.{ "GET", "HEAD", "POST", "PUT", "DELETE", "OPTIONS", "PATCH", "HTTP" }, .types = &.{ "jsonpath", "regex", "xpath", "status", "url", "body", "bytes", "duration", "header" } },
        .ninja => .{ .line_comments = &.{"#"}, .keywords = &.{ "build", "default", "include", "pool", "rule", "subninja" } },
        .rpmspec => .{ .line_comments = &.{"#"}, .keywords = &.{ "Name", "Version", "Release", "Summary", "License", "Source", "BuildRequires", "Requires", "description", "prep", "build", "install", "files", "changelog" }, .case_insensitive = true },
        .gdscript => .{ .line_comments = &.{"#"}, .keywords = &.{ "and", "as", "await", "break", "class", "class_name", "const", "else", "enum", "extends", "for", "func", "if", "in", "is", "match", "not", "or", "return", "signal", "static", "var", "while" }, .types = &.{ "Array", "bool", "Dictionary", "float", "int", "Node", "Object", "String", "Vector2", "Vector3" } },
        .perl => .{ .line_comments = &.{"#"}, .keywords = &.{ "BEGIN", "END", "else", "elsif", "for", "foreach", "if", "last", "local", "my", "next", "our", "package", "return", "say", "state", "sub", "unless", "use", "while" }, .constants = &.{"undef"} },
        .elixir => .{ .line_comments = &.{"#"}, .keywords = &.{ "after", "alias", "case", "catch", "cond", "def", "defmodule", "defp", "do", "else", "end", "fn", "for", "if", "import", "in", "receive", "rescue", "try", "unless", "when" }, .constants = &.{"nil"} },
        .fsharp => .{ .line_comments = &.{"//"}, .block_comments = &.{.{ .open = "(*", .close = "*)" }}, .keywords = &.{ "and", "as", "class", "do", "else", "exception", "for", "fun", "function", "if", "in", "inherit", "interface", "let", "match", "member", "module", "namespace", "open", "rec", "return", "then", "try", "type", "while", "with", "yield" }, .types = &.{ "bool", "char", "float", "int", "list", "obj", "string", "unit" } },
        .ocaml => .{ .block_comments = &.{.{ .open = "(*", .close = "*)" }}, .keywords = &.{ "and", "as", "begin", "class", "do", "done", "else", "end", "exception", "for", "fun", "function", "if", "in", "include", "let", "match", "module", "of", "open", "rec", "sig", "struct", "then", "try", "type", "val", "when", "while", "with" }, .types = &.{ "bool", "bytes", "char", "float", "int", "list", "option", "string", "unit" } },
        .haskell => .{ .line_comments = &.{"--"}, .block_comments = &.{.{ .open = "{-", .close = "-}" }}, .keywords = &.{ "case", "class", "data", "deriving", "do", "else", "if", "import", "in", "instance", "let", "module", "newtype", "of", "then", "type", "where" }, .types = &.{ "Bool", "Char", "Either", "Float", "IO", "Int", "Integer", "Maybe", "String" } },
        .gleam => .{ .line_comments = &.{"//"}, .keywords = &.{ "as", "assert", "case", "const", "fn", "if", "import", "let", "opaque", "pub", "type", "use" }, .types = &.{ "BitArray", "Bool", "Float", "Int", "List", "Nil", "Result", "String" } },
        .commonlisp => .{ .line_comments = &.{";"}, .block_comments = &.{.{ .open = "#|", .close = "|#" }}, .keywords = &.{ "defclass", "defconstant", "defmacro", "defmethod", "defpackage", "defparameter", "defun", "defvar", "do", "dolist", "if", "lambda", "let", "loop", "progn", "quote", "return-from", "setq" } },
        .scheme => .{ .line_comments = &.{";"}, .block_comments = &.{.{ .open = "#|", .close = "|#" }}, .keywords = &.{ "and", "begin", "case", "cond", "define", "define-syntax", "do", "else", "if", "lambda", "let", "let*", "letrec", "or", "quote", "set!" } },
        .julia => .{ .line_comments = &.{"#"}, .block_comments = &.{.{ .open = "#=", .close = "=#" }}, .keywords = &.{ "abstract", "begin", "break", "catch", "const", "else", "elseif", "end", "export", "finally", "for", "function", "global", "if", "import", "let", "local", "macro", "module", "mutable", "return", "struct", "try", "using", "where", "while" }, .types = &.{ "Any", "Bool", "Char", "Float64", "Int", "Nothing", "String", "UInt" } },
        .elm => .{ .line_comments = &.{"--"}, .block_comments = &.{.{ .open = "{-", .close = "-}" }}, .keywords = &.{ "alias", "as", "case", "else", "exposing", "if", "import", "in", "let", "module", "of", "port", "then", "type" }, .types = &.{ "Bool", "Char", "Cmd", "Float", "Int", "List", "Maybe", "Result", "String" } },
        .purescript => .{ .line_comments = &.{"--"}, .block_comments = &.{.{ .open = "{-", .close = "-}" }}, .keywords = &.{ "as", "case", "class", "data", "derive", "do", "else", "forall", "foreign", "if", "import", "in", "instance", "let", "module", "newtype", "of", "then", "type", "where" }, .types = &.{ "Array", "Boolean", "Char", "Either", "Int", "Maybe", "Number", "String", "Unit" } },
        .nim => .{ .line_comments = &.{"#"}, .block_comments = &.{.{ .open = "#[", .close = "]#" }}, .keywords = &.{ "and", "block", "break", "case", "const", "continue", "converter", "defer", "discard", "distinct", "else", "enum", "except", "for", "from", "func", "if", "import", "in", "iterator", "let", "macro", "method", "not", "object", "of", "or", "proc", "raise", "ref", "return", "template", "try", "tuple", "type", "var", "when", "while", "yield" }, .types = &.{ "bool", "byte", "char", "cstring", "float", "int", "pointer", "seq", "string", "uint", "void" } },
    };
}
