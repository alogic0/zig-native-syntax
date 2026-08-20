# Embedded Language Composition

## Region Contract

An embedded language region is a half-open byte range in the original source. A composed backend
passes the borrowed region slice to a nested backend through `composition.highlightEmbedded`. The
helper validates the parent range, creates a temporary capture sink whose source length matches the
slice, and translates each validated nested capture by adding the parent region's start offset.

The destination sink must describe the complete parent source. No translated capture can cross the
embedded region boundary. Nested captures are copied into caller-owned storage, so none borrow
temporary parser state.

## Scope And Boundary Precedence

The complete embedded region receives the `embedded` scope. Parent captures and nested captures are
otherwise retained unchanged. At overlapping bytes the renderer combines their scopes in stable
`Scope` enum order; no backend-specific priority discards another classification.

Regions and captures use half-open boundaries. A capture ending at the start of an embedded region,
or starting at its end, is adjacent rather than overlapping. Empty regions invoke the nested backend
with empty source but produce no stored `embedded` capture.

## Failure Behavior

Invalid parent regions fail before the nested backend runs. Allocation failures and shared backend
contract errors propagate normally. Language syntax errors remain the nested backend's recovery
responsibility and are not promoted to composition errors. Captures already present in the parent
sink remain owned by the caller if a later allocation fails.
