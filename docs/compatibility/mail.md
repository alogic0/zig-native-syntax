# E-mail Highlighting Compatibility

The dependency-free `mail` backend recognizes RFC-style header names and
folded values, e-mail addresses, HTTP links, nested quote prefixes, and the
conventional signature separator. It is verified as a source-preserving
lexical scanner on messages and reply threads.

The scanner does not decode MIME, encoded words, transfer encodings, address
groups, or attachments, and it does not validate an RFC message. A malformed
header ends header mode without hiding subsequent body text.
