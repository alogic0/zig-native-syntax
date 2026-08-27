# Starlark highlighting

The verified Starlark backend parses function heads and parameters, rule calls,
keyword arguments, member selectors, bindings, `load` forms, comments, strings,
escapes, and values. The `bazel` and `bzl` labels route here; `.bazelrc` is
intentionally excluded because its command-line configuration syntax differs.
