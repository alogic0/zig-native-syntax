# Nix highlighting

The verified structural Nix backend distinguishes `let` bindings, attribute
assignments and paths, simple and attribute-set function parameters, inherited
attributes, common builtins, and `${...}` expressions inside ordinary and
indented strings. It preserves tolerant recovery and does not evaluate Nix or
resolve imported values.
