# TOML Highlighting Compatibility

The dependency-free `toml` backend is a byte-oriented lexical scanner. It
recognizes bare and quoted keys, table paths, basic and literal strings,
multiline strings, basic-string escapes, comments, booleans, number/date-like
tokens, and structural delimiters.

The scanner is not a TOML validator. It does not validate Unicode escapes,
date/time ranges, numeric bases and separators, duplicate keys, table
redefinition, dotted-key relationships, or newline restrictions on string
forms. Recognizable incomplete strings extend through end of input; unknown
bytes remain plain and scanning resumes at the next lexical construct.
