# Git Rebase Highlighting Compatibility

The `git-rebase` backend is a verified composition. It recognizes interactive
rebase commands, commit object names, labels, subjects, and comments, and sends
`exec` command bodies to the verified Bash parser. It does not validate the
rebase graph or Git object existence.
