//! The `rust-template` binary: installs the error reporter and hands the
//! process arguments to [`rust_template::cli::run`].

use std::{io, process::ExitCode};

fn main() -> color_eyre::Result<ExitCode> {
    color_eyre::install()?;
    rust_template::cli::run(std::env::args_os(), &mut io::stdout().lock())
}
