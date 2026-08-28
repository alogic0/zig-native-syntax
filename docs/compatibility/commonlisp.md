# Common Lisp Highlighting Compatibility

The verified structural Common Lisp backend combines the shared lexical
scanner with the shared Lisp-family S-expression scanner. It recognizes
package, function, generic-function, method, macro, class, structure, type,
variable, parameter, and constant definitions; lambda lists; class slots;
`let` bindings; calls; keywords; booleans; and quoted data.

The scanner is bounded and source-preserving around incomplete forms and nested
block comments. It does not expand reader macros or macros, resolve packages,
apply the full Common Lisp reader, infer types, or evaluate source.
