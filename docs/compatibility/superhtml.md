# SuperHTML Syntax API Compatibility

## Dependency Boundary

The HTML, XML, CSS, and composed SuperHTML adapters use the independently consumable fork at
`alogic0/superhtml`. They do not use the copy vendored in Zine. The fork retains
`kristoff-it/superhtml` as its upstream project and carries a small syntax-consumer API layer.

The pinned compatibility revision is `398343534f5a3c57e2a82792a3282234526774d5`, whose package
version is `0.7.0` and whose declared minimum Zig version is compatible with this project's pinned
compiler.

The fork publishes dependency-free syntax modules for this integration:

- `html-tokenizer` for HTML, XML, and SuperHTML markup tokenization;
- `css-tokenizer` for CSS tokenization, including opt-in comment tokens;
- `template-syntax` for SuperHTML directive and embedded-expression discovery.

The dependency is configured with `tokenizers_only = true`, so loading these modules does not
configure the SuperHTML CLI, LSP, VM, semantic AST, Scripty, Tracy, or generated language registry.
Its source is fetched with the package so clean consumers can discover public modules on their first
build, but it is configured only when at least one of `backend-html`, `backend-xml`, `backend-css`,
or `backend-superhtml` is enabled.

## Upgrade Contract

Before updating the pin, verify that:

- all three lightweight modules remain independently consumable together;
- HTML mode still supports `return_attrs` and reports tag-name and attribute ranges;
- XML remains a distinct tokenizer language mode;
- CSS tokens still expose source spans through `Token.span()` and comments through
  `return_comments`;
- `template-syntax` still reports directive names and embedded expression spans;
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

The CSS backend consumes `css-tokenizer` for identifiers, functions, at-keywords, hashes, strings,
URLs, numbers, percentages, dimensions, comments, errors, delimiters, and structural punctuation.
It enables `return_comments`; the adapter no longer maintains a duplicate comment scanner.

A bounded declaration lookahead distinguishes property names from selectors and values. It tracks
quotes, parentheses, and square brackets and declines to call a name a property when the construct
reaches an opening rule brace first. This is highlighting context, not CSS validation.

The upstream CSS AST is intentionally not used because its current parser contains `TODO` panic
paths for valid but unsupported constructs, including attribute selectors. Malformed snippets must
remain data rather than terminate highlighting. Invalid tokenizer spans are therefore ignored while
the shared renderer preserves their original bytes.

## Composed SuperHTML Adapter

The SuperHTML backend runs the markup adapter in `.superhtml` mode and passes tokenizer-reported
attributes to `template-syntax`. That module owns the rules for locating directive names and
Scripty expression regions: values of `:if`, `:loop`, `:text`, and `:html` are embedded expressions,
ordinary attribute values beginning with `$` are expressions, and `:else` has no embedded value.

Directive names retain `attribute` and add `special`. Quotation marks retain `string`, while the
value contents drop the parent string classification and receive `embedded` plus scopes from the
independently selectable Scripty backend. Markup and expression errors recover locally; a missing
attribute range remains escaped markup rather than being guessed by a second parser.

The composition corpus covers adjacent directives, single- and double-quoted attributes, multiline
expressions, delimiter-shaped bytes inside Scripty strings, malformed expressions followed by valid
ones, and truncated markup. Core composition tests additionally randomize parent and embedded range
boundaries to verify every translated capture remains inside its delegated region.
