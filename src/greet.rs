//! The example domain logic behind `rust-template greet`.
//!
//! Replace it with your own; it exists to show the shape: pure functions,
//! data in, data out, no I/O.

/// Builds the greeting for `name`.
///
/// Surrounding whitespace is trimmed and an empty name falls back to
/// `"world"`. With `shout`, the whole greeting is upper-cased.
///
/// ```
/// use rust_template::greet::greeting;
///
/// assert_eq!(greeting("Ferris", false), "Hello, Ferris!");
/// assert_eq!(greeting("  ", true), "HELLO, WORLD!");
/// ```
#[must_use]
pub fn greeting(name: &str, shout: bool) -> String {
    let name = Some(name.trim()).filter(|n| !n.is_empty()).unwrap_or("world");
    let text = format!("Hello, {name}!");
    if shout { text.to_uppercase() } else { text }
}

#[cfg(test)]
mod tests {
    use super::greeting;

    #[test]
    fn greets_by_name() {
        assert_eq!(greeting("Ferris", false), "Hello, Ferris!");
    }

    #[test]
    fn blank_name_falls_back_to_world() {
        for blank in ["", " ", "\t\n"] {
            assert_eq!(greeting(blank, false), "Hello, world!", "{blank:?}");
        }
    }

    #[test]
    fn shout_upper_cases_everything() {
        assert_eq!(greeting("ferris", true), "HELLO, FERRIS!");
    }

    #[test]
    fn non_ascii_names_survive() {
        assert_eq!(greeting("Zoë", true), "HELLO, ZOË!");
    }
}
