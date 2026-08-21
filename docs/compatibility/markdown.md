# Markdown Highlighting Compatibility

The optional `native_syntax_markdown` module is enabled with
`-Dbackend-markdown=true`. It uses the independently pinned
`zig-markdown-parser` package through its public immutable document traversal
API. The parser reports half-open byte spans into the caller's original source;
the adapter converts those spans into captures without rendering or rewriting
the Markdown.

The backend classifies:

- headings as `markup_heading`;
- emphasis, strong text, and strikethrough as their matching markup scopes;
- links, images, footnote references, and footnote definitions as
  `markup_link`;
- inline and fenced code as `markup_code`;
- block quotes as `markup_quote`;
- unordered and ordered list markers, including task markers, as
  `markup_list`;
- thematic breaks as `special` and hard line breaks as `escape`;
- raw inline and block HTML as `embedded`.

Container and inline scopes may overlap. The shared renderer normalizes those
captures while preserving every source byte and safely escaping unclassified
gaps. Invalid UTF-8 and incomplete constructs remain source-preserving; syntax
that the parser does not recognize is emitted as escaped plain text rather than
reported as a highlighting error.

The backend does not recursively highlight raw HTML. It marks the region as
embedded so a future composed backend can delegate it to the HTML adapter.
Likewise, fenced code is one `markup_code` region: resolving its info string and
running another language backend is deferred because aliases and enabled
backends are consumer-owned policy.

The module's canonical name is `markdown`. Aliases such as `md`, `smd`, and
`supermd` are deliberately not part of the package API. SuperMD directives and
page semantics remain owned by Zine and are not interpreted by this source
highlighter.
