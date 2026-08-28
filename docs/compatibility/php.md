# PHP highlighting

The verified structural PHP backend separates markup from `<?php`, `<?=`, and
short PHP regions. Markup tags and attributes are highlighted independently;
PHP regions classify declarations, parameters, member access, calls, and
constructor uses in addition to their lexical tokens. A fence without an
opening marker is treated as a PHP snippet. PHP 8 `#[...]` attributes,
anonymous closures, multiline quoted strings, and heredoc/nowdoc bodies are
kept structurally separate; closing-tag text inside them does not terminate a
PHP region.
