# DTD Compatibility

The DTD backend uses a dedicated, dependency-free XML declaration scanner. It
recognizes element, attribute-list, entity, notation, and document-type
declarations; element content models; attribute names and types; default
keywords and enumerations; general and parameter entity references; quoted
literals; comments; processing instructions; and ignored conditional sections.

The scanner follows the declaration forms in XML 1.0 but deliberately does not
validate content models, expand entities, resolve external identifiers, or
enforce declaration nesting. Ignored conditional sections are treated as
comment content. Unterminated declarations, strings, comments, and conditional
sections recover at end of input, and malformed bytes retain the shared
arbitrary-byte behavior.
