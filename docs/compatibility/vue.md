# Vue highlighting

The verified Vue backend composes the source-preserving component markup
scanner with the JavaScript parser for `<script>` bodies and `{{ ... }}`
template interpolations. Markup tags, attributes, strings, comments, and
malformed boundaries remain bounded by the outer scanner. Style bodies remain
embedded text until a core CSS composition is available.
