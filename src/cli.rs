//! Command-line interface: the clap derive tree and [`run`].
//!
//! [`run`] parses the arguments and dispatches to a subcommand. Output goes
//! to the writer it is given, never straight to stdout, so tests can capture
//! it.

use std::{ffi::OsString, io::Write, process::ExitCode};

use clap::{Parser, Subcommand};
use color_eyre::eyre::WrapErr;

use crate::greet;

/// Top-level arguments.
#[derive(Debug, Parser)]
#[command(name = "rust-template", version, about, long_about = None)]
pub struct Cli {
    /// The subcommand to run; `greet` when omitted.
    #[command(subcommand)]
    pub command: Option<Command>,
}

/// The subcommands.
#[derive(Debug, Subcommand)]
pub enum Command {
    /// Print a greeting.
    Greet {
        /// Who to greet.
        #[arg(env = "RUST_TEMPLATE_NAME", default_value = "world")]
        name: String,
        /// Upper-case the greeting.
        #[arg(long)]
        shout: bool,
    },
}

impl Default for Command {
    fn default() -> Self {
        Self::Greet { name: String::from("world"), shout: false }
    }
}

/// Parses `args` (the first item is the program name) and runs the
/// subcommand, writing its output to `out`.
///
/// `--help` and `--version` are written to `out` and succeed; a usage error
/// is printed to stderr by clap and exits 2, clap's convention.
///
/// # Errors
///
/// Returns an error when writing to `out` fails.
pub fn run<I, T>(args: I, out: &mut impl Write) -> color_eyre::Result<ExitCode>
where
    I: IntoIterator<Item = T>,
    T: Into<OsString> + Clone,
{
    let cli = match Cli::try_parse_from(args) {
        Ok(cli) => cli,
        Err(err) if err.use_stderr() => {
            err.print().wrap_err("printing the usage error")?;
            return Ok(ExitCode::from(2));
        }
        Err(err) => {
            write!(out, "{}", err.render()).wrap_err("writing help")?;
            return Ok(ExitCode::SUCCESS);
        }
    };

    match cli.command.unwrap_or_default() {
        Command::Greet { name, shout } => {
            writeln!(out, "{}", greet::greeting(&name, shout)).wrap_err("writing the greeting")?;
        }
    }
    Ok(ExitCode::SUCCESS)
}

#[cfg(test)]
mod tests {
    use clap::CommandFactory;

    use super::*;

    fn output(args: &[&str]) -> (ExitCode, String) {
        let mut out = Vec::new();
        let code = run(args, &mut out).unwrap();
        (code, String::from_utf8(out).unwrap())
    }

    #[test]
    fn clap_definition_is_consistent() {
        Cli::command().debug_assert();
    }

    #[test]
    fn no_subcommand_greets_the_world() {
        assert_eq!(output(&["rust-template"]).1, "Hello, world!\n");
    }

    #[test]
    fn greet_takes_a_name_and_shout() {
        assert_eq!(output(&["rust-template", "greet", "Ferris", "--shout"]).1, "HELLO, FERRIS!\n");
    }

    #[test]
    fn version_goes_to_the_writer() {
        let (code, text) = output(&["rust-template", "--version"]);
        assert_eq!(code, ExitCode::SUCCESS);
        assert_eq!(text, format!("rust-template {}\n", env!("CARGO_PKG_VERSION")));
    }

    #[test]
    fn usage_error_exits_two() {
        let (code, text) = output(&["rust-template", "--no-such-flag"]);
        assert_eq!(code, ExitCode::from(2));
        assert_eq!(text, "");
    }
}
