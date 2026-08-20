# Classification Model

## Decision

The public highlighting taxonomy is a flat, language-neutral `Scope` enum. Scopes are composable:
a backend can apply multiple scopes to the same source range instead of encoding combinations such
as "builtin type" or "documentation comment" as separate enum values.

This keeps the shared model independent of any parser's capture vocabulary while preserving useful
semantic combinations for CSS selectors.

## Stable Class Names

Each scope maps to one library-controlled CSS class prefixed with `syntax-`. The renderer never
constructs class names from source text, a fence language, or backend-provided strings.

Examples:

| Scope | CSS class |
| --- | --- |
| `keyword` | `syntax-keyword` |
| `builtin` | `syntax-builtin` |
| `type` | `syntax-type` |
| `markup_heading` | `syntax-markup-heading` |

A builtin type can therefore produce both `syntax-builtin` and `syntax-type` over the same bytes.
Capture normalization and deterministic class ordering are defined separately from the taxonomy.

## Initial Vocabulary

The initial scopes cover the shared roles observed in Zig, Ziggy, Ziggy Schema, HTML, XML, CSS,
SuperHTML, Scripty, Markdown, Rust, and shell highlighting:

- declarations and names: `attribute`, `constant`, `constructor`, `function`, `label`, `macro`,
  `namespace`, `parameter`, `property`, `tag`, `type`, and `variable`;
- lexical roles: `boolean`, `builtin`, `comment`, `documentation`, `embedded`, `escape`, `invalid`,
  `keyword`, `number`, `operator`, `punctuation`, `special`, and `string`;
- Markdown roles: `markup_code`, `markup_emphasis`, `markup_heading`, `markup_link`, `markup_list`,
  `markup_quote`, `markup_strikethrough`, and `markup_strong`.

Whitespace and ordinary source text remain unclassified. The renderer preserves and escapes those
gaps without wrapping them in a scope element.

## Mapping Rules

- Parser-specific subcategories map to the closest shared scope. For example, function calls and
  function declarations both map to `function` unless a future requirement justifies a stable
  distinction.
- A role that is useful only in combination is represented by overlapping scopes. A documentation
  comment uses `comment` and `documentation`; a builtin type uses `builtin` and `type`.
- Syntax known to be invalid can use `invalid`, but malformed input does not have to be classified as
  invalid. Leaving uncertain bytes unclassified is always acceptable.
- `embedded` identifies a region belonging to another language. The nested backend supplies the
  lexical or semantic scopes inside that region when composition is enabled.
- Markdown scopes describe source markup, not the rendered document structure.

## Compatibility

The taxonomy is experimental until the first package release. Before that release, real backends and
the Zine integration may demonstrate that a scope should be added, renamed, combined, or removed.

After a stable release:

- changing an existing CSS class or its meaning is a breaking change;
- removing or renaming a scope is a breaking change;
- adding a scope is documented in release notes because exhaustive consumer switches may require an
  update, even when the package's semantic-versioning policy treats the addition as compatible.

Consumer-specific aliases and theme colors remain outside this model.
