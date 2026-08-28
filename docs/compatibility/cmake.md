# CMake Highlighting Compatibility

The dependency-free `cmake` backend uses a single-pass tolerant structural
scanner. It recognizes line and bracket comments, bracket and quoted arguments,
command calls, function and macro declarations, formal parameters, variable
bindings and references, targets, properties, generator expressions, control
flow, primitive values, operators, and punctuation.

The scanner is not a CMake evaluator: it does not expand variables or generator
expressions, execute commands, or validate command signatures. Unterminated
quoted and bracket arguments recover at end of input. Exact tests cover nested
references and generator expressions, declarations, target/property commands,
malformed input, and source preservation.
