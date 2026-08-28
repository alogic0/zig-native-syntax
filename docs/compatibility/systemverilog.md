# SystemVerilog Highlighting Compatibility

The verified structural SystemVerilog backend combines the shared lexical
scanner with an owned tolerant declaration parser. It recognizes module,
interface, program, class, and package declarations; imports; ports,
parameters, signals, typedefs, and enum constants; functions and tasks;
member names, system calls, compiler directives, attributes, escaped
identifiers, and based numeric literals.

The parser is bounded and source-preserving around incomplete declarations. It
does not elaborate designs, resolve types or instances, expand macros, evaluate
constant expressions, validate assertions, or compile the source.
