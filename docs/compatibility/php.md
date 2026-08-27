# PHP highlighting

The verified structural PHP backend separates markup from `<?php`, `<?=`, and
short PHP regions. Markup tags and attributes are highlighted independently;
PHP regions classify declarations, parameters, member access, calls, and
constructor uses in addition to their lexical tokens. A fence without an
opening marker is treated as a PHP snippet.
