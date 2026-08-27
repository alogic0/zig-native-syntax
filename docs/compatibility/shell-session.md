# Shell-session highlighting

The verified shell-session backend recognizes `$`, `%`, continuation, and
conventional `user@host:path$` prompts. It marks prompt text and delegates only
the following command body to the verified Bash parser. Output and diagnostic
lines remain unclassified plain text. The `console`, `sh-session`, and
`bash-session` labels route to this backend.
