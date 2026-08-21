//! Native Rust highlighting fixture.

#[derive(Debug, Clone)]
pub struct Entry<'a> {
    name: &'a str,
    value: u64,
}

/* outer /* nested */ complete */
pub fn render<'a>(entry: &'a Entry<'a>) -> bool {
    let cooked = "line\n<&>";
    let bytes = b"bytes\x20";
    let raw = r#"raw "quoted" <&>"#;
    let byte_raw = br##"byte raw <&>"##;
    let letter = 'x';
    let byte = b'Z';
    let values = vec![0xff_u8, 1_000usize, 1.5e-2f64];
    println!("{cooked} {bytes:?} {raw} {byte_raw:?} {letter} {byte} {values:?}");
    entry.value > 0 && true
}

const INCOMPLETE: &str = r###"unterminated raw source
