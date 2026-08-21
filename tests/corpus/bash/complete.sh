#!/usr/bin/env bash

set -eu
name=${name:-world}

if [[ -n "$name" ]]; then
    printf '%s\n' "hello $name"
    printf '%s\n' "$(printf '%s' "$name")"
fi

for value in 1 2 3; do
    echo $((value + 1))
done

cat <<'EOF'
literal $body <&>
EOF

cat <<-TABS
	tab-indented
	TABS

echo "unterminated ${name
