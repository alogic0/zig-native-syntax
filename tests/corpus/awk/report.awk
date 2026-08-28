@include "join.awk"

BEGIN {
    FS = ","
    OFS = "\t"
    scale = 100
}

$3 ~ /^[[:digit:]]+(\.[[:digit:]]+)?$/ {
    totals[$1] += $3 / scale
}

function normalize(value, fallback, result) {
    result = value > 0 ? value : fallback
    return sprintf("%.2f", result)
}

END {
    for (name in totals) {
        printf "%s%s%s\n", name, OFS, normalize(totals[name], 1)
    }
}

# Ignore malformed rows.
