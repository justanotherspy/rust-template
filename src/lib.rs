//! Library half of `rust-template`.
//!
//! The binary in `main.rs` is a thin shell around [`cli::run`], so
//! everything worth testing lives here and is reachable from unit tests,
//! doctests and `tests/`.

pub mod cli;
pub mod greet;
