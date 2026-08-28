# Nix highlighting

The verified structural Nix backend distinguishes `let` bindings from nested
attribute sets, static and dynamic attribute paths, simple and attribute-set
function parameters, inherited attributes, common builtins, path/search-path
and URI literals, and `${...}` expressions inside ordinary and indented
strings. Nix indented-string escapes such as `''${...}` remain literal. It
preserves tolerant recovery and does not evaluate Nix or resolve imported
values. Embedded-expression highlighting is capped at 32 levels; deeper valid
input remains escaped and marked as embedded text without unbounded recursion.
