# ML-Family Scanner Performance

The OCaml and F# backends use one lexical source traversal followed by an
in-place structural refinement of emitted captures. This replaced the former
generic lexical traversal plus a second structural source traversal.

## Reproducing the benchmark

Run both optimization modes from the repository root:

```sh
./build.sh benchmark-ml -- 2000 64
./build.sh benchmark-ml-small -- 2000 64
```

The first argument is the iteration count. The second is the number of copies
used for the repeated-input profile. Each command measures the focused OCaml
and F# corpus as-is and as a contiguous repeated input. The output reports
throughput, per-iteration latency, captures, allocation calls, requested bytes,
peak bytes, and a checksum.

## Comparison

The comparison was recorded on 2026-08-27 on an x86_64 AMD Ryzen 7 7840HS
using the repository's Zig 0.17.0-dev.1756+613c03321 toolchain. Each command
was run three times; the table contains median throughput.

- Baseline: `8bd7a12`, the two-source-traversal implementation.
- Candidate: `6764e57`, static capture refinement.
- Harness: `7a4a9b9`, applied unchanged to both revisions.
- Repeated inputs: 64 copies of the corresponding focused corpus.
- Iterations: 2,000 per sample.

| Mode | Language | Profile | Two-pass | Capture refinement | Ratio |
| --- | --- | --- | ---: | ---: | ---: |
| ReleaseFast | OCaml | corpus | 34.74 MiB/s | 63.34 MiB/s | 1.823x |
| ReleaseFast | OCaml | repeated | 33.28 MiB/s | 55.97 MiB/s | 1.682x |
| ReleaseFast | F# | corpus | 32.79 MiB/s | 53.32 MiB/s | 1.626x |
| ReleaseFast | F# | repeated | 32.68 MiB/s | 57.84 MiB/s | 1.770x |
| ReleaseSmall | OCaml | corpus | 17.08 MiB/s | 32.81 MiB/s | 1.921x |
| ReleaseSmall | OCaml | repeated | 17.55 MiB/s | 32.17 MiB/s | 1.833x |
| ReleaseSmall | F# | corpus | 16.94 MiB/s | 29.95 MiB/s | 1.768x |
| ReleaseSmall | F# | repeated | 18.04 MiB/s | 33.70 MiB/s | 1.868x |

Allocation behavior was unchanged: corpus inputs required 6 allocation calls,
10,968 requested bytes, and 7,824 peak bytes; repeated inputs required 9 calls,
340,824 requested bytes, and 291,000 peak bytes. Capture refinement emits
slightly more captures than the baseline, but the candidate's exact
rendered-output regressions remain green and it is still substantially faster.

The revisions are not capture-for-capture identical. The candidate fixes
apostrophe type-variable scanning and deliberately normalizes whole attributes,
line directives, and labelled parameters. Its focused-corpus capture counts
are 181 versus 172 for OCaml and 169 versus 161 for F#. The throughput gain is
therefore not explained by emitting less highlighting data.

The viewer's ReleaseSmall Wasm measured 599,806 bytes with capture refinement,
compared with 599,812 bytes for the former two-pass implementation.

## Decision

Keep static capture refinement. Its smallest measured throughput improvement is
62.6%, it adds no allocation or Wasm-size cost, and the exact OCaml/F# rendered
HTML regressions remain green. These figures are local evidence rather than
portable performance guarantees; re-run the benchmark after material scanner,
capture-storage, allocator, or compiler changes.
