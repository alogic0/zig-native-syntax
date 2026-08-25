# Capture And Range Model

## Decision

Source positions use `usize` byte offsets into source borrowed from the caller. A `Span` is a
half-open range `[start, end)`. A `Capture` combines one span with one language-neutral scope.

This model matches Zig slice indexing, avoids line-and-column conversion in backends, and does not
impose the narrower offset types used by individual parser packages.

## Validation

A span is valid for a source when:

```text
start <= end <= source.len
```

When the complete source is valid UTF-8, both offsets must also be UTF-8 code-point boundaries.
`validateCaptures` checks ordinary ranges for the complete capture set first, then checks the source
once and reports `MisalignedUtf8Boundary` for a split code point. Backends and the HTML renderer call
this shared validation path. They reject misaligned captures rather than moving or merging them.

When the source is not valid UTF-8, captures retain arbitrary-byte behavior. This lets tolerant
backends classify malformed bytes and lets the renderer preserve them without imposing Unicode
semantics on byte input.

Construction rejects reversed ranges. Validation against the source length rejects out-of-bounds
ranges before any slice operation. The implementation does not compute `start + length`, avoiding
offset-overflow ambiguity.

Empty spans are valid. They carry no source bytes and renderers ignore them.

## Relationships And Overlap

Captures do not have to be sorted or disjoint. The model permits:

- adjacent captures;
- identical captures with different scopes;
- captures nested inside other captures;
- crossing captures such as `[0, 5)` and `[3, 8)`.

Crossing captures cannot always be represented as directly nested HTML elements. The renderer will
therefore normalize capture boundaries into non-overlapping source segments. Each segment receives
the deterministic set of scopes active over that byte range.

Allowing overlap is necessary for composable classifications. For example, the same bytes can be a
`builtin` and a `type`, while a documentation comment can be both `comment` and `documentation`.

## Ownership

- Spans and captures own no source memory.
- A source slice must outlive classification and rendering.
- Backends may allocate capture storage, but returned ranges contain only offsets and scopes.
- Parser-owned token or AST memory must not be referenced by a returned capture.

## Error Policy

Reversed, out-of-bounds, and valid-source UTF-8-boundary violations are backend or integration
errors, not malformed-language errors. Ordinary range errors take precedence over boundary errors
and are reported before rendering. Invalid or incomplete source remains representable because a
backend can classify only the regions it understands and leave all other bytes unclassified.

## Compatibility

The offset type and half-open convention are public API commitments once the package reaches its
first stable release. A future incremental editor API may add line indexes or changed ranges without
changing the meaning of `Span`.
