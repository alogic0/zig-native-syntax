# Benchmark Baselines

These measurements provide review evidence for material parser, scanner,
capture-storage, allocator, and compiler changes. They are not CI thresholds:
shared runners and developer machines have too much timing variance for a
single portable pass/fail number. Re-run the same commands, disclose the test
environment, and compare medians when a change could affect performance.

## Reproduction

From the repository root:

```sh
./build.sh benchmark-syntax-core -- 500
./build.sh benchmark-ml -- 2000 64
./build.sh benchmark-ml-small -- 2000 64
```

The recorded sample used revision `618c32a`, Zig
`0.17.0-dev.1756+613c03321`, and Linux x86_64 on an AMD Ryzen 7 7840HS with 16
logical CPUs. Each command was run three times on 2026-08-29; the tables report
median throughput. Allocation counts and peak bytes were identical across all
three runs.

## Syntax-Core Comparison

This harness compares the retained lexical baselines with the structural Bash,
JavaScript, and Rust backends on their focused corpora in ReleaseFast mode.

| Backend | Lexical MiB/s | Structural MiB/s | Ratio | Allocation calls, lexical / structural | Peak bytes, lexical / structural |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bash | 349.33 | 112.88 | 0.301x | 5 / 16 | 2,040 / 3,321 |
| JavaScript | 122.50 | 90.45 | 0.726x | 4 / 13 | 1,944 / 3,172 |
| Rust | 116.52 | 80.85 | 0.694x | 5 / 15 | 5,016 / 6,619 |

The comparison measures the cost of richer structural classification on small
inputs; it is not a ranking between languages. Capture counts and checksums are
also emitted by the harness so a suspicious speed change can be distinguished
from doing less work.

## ML-Family Throughput

The corpus profile uses the focused source once. The repeated profile joins 64
copies to expose scaling behavior on larger inputs.

| Mode | Language | Profile | MiB/s | Allocation calls | Peak bytes |
| --- | --- | --- | ---: | ---: | ---: |
| ReleaseFast | OCaml | corpus | 63.56 | 6 | 7,824 |
| ReleaseFast | OCaml | repeated | 57.52 | 9 | 291,000 |
| ReleaseFast | F# | corpus | 53.79 | 6 | 7,824 |
| ReleaseFast | F# | repeated | 58.80 | 9 | 291,000 |
| ReleaseSmall | OCaml | corpus | 29.22 | 6 | 7,824 |
| ReleaseSmall | OCaml | repeated | 30.52 | 9 | 291,000 |
| ReleaseSmall | F# | corpus | 28.04 | 6 | 7,824 |
| ReleaseSmall | F# | repeated | 32.01 | 9 | 291,000 |

Corpus inputs requested 10,968 bytes across their allocations. Repeated inputs
requested 340,824 bytes. Those deterministic allocation measurements are often
more comparable across machines than elapsed time, but they remain review
signals rather than fixed budgets.
