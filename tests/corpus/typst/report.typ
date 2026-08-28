#import "@preview/cetz:0.3.1": canvas
#set page(width: 180mm, margin: 12mm)
#let accent = rgb("#4f78d1")
#let enabled = true
#let note = "viewer\nreport"
#let badge(body, fill: accent) = box(fill: fill, inset: 4pt)[#body]

= Quarterly report <report>

See @report and #link("https://example.com")[the dashboard].
The escaped marker is \# and `#raw` remains literal.

$ sum_(i=1)^n i = (n (n + 1)) / 2 $

#show heading: it => [*#it.body*]

```rust
fn main() {
    println!("not Typst #code");
}
```

// The report is generated from source data.
