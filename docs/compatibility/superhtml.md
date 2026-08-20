# SuperHTML Syntax API Compatibility

## Dependency Boundary

The HTML, XML, and CSS adapters use the independently consumable upstream package at
`kristoff-it/superhtml`. They do not use the copy vendored in Zine.

The pinned compatibility revision is `23ef2f44ca0df2d2e05a0be3874370553c5b591d`, whose package
version is `0.7.0` and whose declared minimum Zig version is compatible with this project's pinned
compiler.

SuperHTML currently publishes one Zig module named `superhtml`. Its public root exports the required
syntax APIs as:

- `superhtml.html.Tokenizer` for HTML and XML;
- `superhtml.css.Tokenizer` for CSS.

There are no smaller independently selectable HTML-only or CSS-only modules in the upstream build.
The adapters therefore import the root module but use only these public tokenizer declarations.
The dependency remains lazy and is configured only when at least one of `backend-html`,
`backend-xml`, `backend-css`, or `backend-superhtml` is enabled.

## Upgrade Contract

Before updating the pin, verify that:

- both tokenizer declarations remain public through the same module;
- HTML mode still supports `return_attrs` and reports tag-name and attribute ranges;
- XML remains a distinct tokenizer language mode;
- CSS tokens still expose source spans through `Token.span()`;
- the package's declared Zig version remains compatible with this project.

`tests/superhtml_api.zig` is the compile-and-run probe for this boundary. Adapter corpus tests own
the behavioral compatibility requirements added by later phases.

## HTML And XML Adapter Boundary

The HTML and XML backends use the same tokenizer with distinct `.html` and `.xml` modes. They
classify tokenizer-reported tag names, attributes, values, comments, doctypes, text entities, and
parse errors. A bounded structural pass derives delimiters and assignment punctuation from those
reported ranges without attempting to parse document structure.

Ordinary text is intentionally unclassified. Contents of `script` and `style` elements are also
left unclassified until a composed backend owns their nested-language policy. Malformed input is
highlighted as far as the tokenizer reports reliable ranges; remaining bytes are preserved and
escaped by the shared renderer.

SuperHTML's XML tokenizer reports processing instructions through its bogus-comment token path. The
adapter recognizes the tokenizer-provided `<?...?>` range and maps it to `special`; it does not
attempt to interpret the instruction body.

## CSS Adapter Boundary

The CSS backend consumes `superhtml.css.Tokenizer` for identifiers, functions, at-keywords, hashes,
strings, URLs, numbers, percentages, dimensions, errors, delimiters, and structural punctuation.
The tokenizer does not emit comments, so the adapter uses a bounded byte scan to reserve `/*...*/`
ranges before mapping tokens. Tokens wholly inside those ranges are ignored.

A bounded declaration lookahead distinguishes property names from selectors and values. It tracks
quotes, parentheses, and square brackets and declines to call a name a property when the construct
reaches an opening rule brace first. This is highlighting context, not CSS validation.

The upstream CSS AST is intentionally not used because its current parser contains `TODO` panic
paths for valid but unsupported constructs, including attribute selectors. Malformed snippets must
remain data rather than terminate highlighting. Invalid tokenizer spans are therefore ignored while
the shared renderer preserves their original bytes.

## Composed SuperHTML Adapter

The SuperHTML backend runs the markup adapter in `.superhtml` mode and uses tokenizer-reported
attribute ranges to locate Scripty expressions. Values of `:if`, `:loop`, `:text`, and `:html` are
embedded expressions. Ordinary attribute values beginning with `$` are expressions as well.
`:else` is classified as a directive but has no embedded value.

Directive names retain `attribute` and add `special`. Quotation marks retain `string`, while the
value contents drop the parent string classification and receive `embedded` plus scopes from the
independently selectable Scripty backend. Markup and expression errors recover locally; a missing
attribute range remains escaped markup rather than being guessed by a second parser.
