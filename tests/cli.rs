//! End-to-end tests: run the built binary as a user would.

// Integration tests are not `#[cfg(test)]` modules, so clippy.toml's
// test-only allowances do not reach them.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use std::process::{Command, Output};

fn run(args: &[&str]) -> Output {
    Command::new(env!("CARGO_BIN_EXE_rust-template"))
        .args(args)
        .env_remove("RUST_TEMPLATE_NAME")
        .output()
        .expect("the binary runs")
}

fn stdout(output: &Output) -> &str {
    std::str::from_utf8(&output.stdout).unwrap()
}

#[test]
fn greets_by_default() {
    let output = run(&[]);
    assert!(output.status.success());
    assert_eq!(stdout(&output), "Hello, world!\n");
}

#[test]
fn greet_reads_the_name_from_the_environment() {
    let output = Command::new(env!("CARGO_BIN_EXE_rust-template"))
        .arg("greet")
        .env("RUST_TEMPLATE_NAME", "Ferris")
        .output()
        .unwrap();
    assert!(output.status.success());
    assert_eq!(stdout(&output), "Hello, Ferris!\n");
}

#[test]
fn version_names_the_crate_version() {
    let output = run(&["--version"]);
    assert!(output.status.success());
    assert!(stdout(&output).contains(env!("CARGO_PKG_VERSION")));
}

#[test]
fn unknown_flag_is_a_usage_error() {
    let output = run(&["--definitely-not-a-flag"]);
    assert_eq!(output.status.code(), Some(2));
    assert_eq!(stdout(&output), "");
    assert!(String::from_utf8_lossy(&output.stderr).contains("--definitely-not-a-flag"));
}
