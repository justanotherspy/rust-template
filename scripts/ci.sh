#!/usr/bin/env bash
# Full local CI, the same gate the GitHub workflow runs: formatting, strict
# clippy, shellcheck, tests, doctests, rustdoc, and (when installed)
# cargo-deny, cargo-shear and actionlint.
set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
skip() { echo "$1 not installed; skipping (run scripts/setup.sh --all)"; }

step "cargo fmt --check";  cargo fmt --check
step "cargo clippy";       cargo clippy --all-targets --all-features --locked -- -D warnings
step "shellcheck"
if command -v shellcheck >/dev/null; then
  shellcheck scripts/*.sh .claude/hooks/*.sh .githooks/*
else
  skip shellcheck
fi
step "cargo nextest run";  cargo nextest run --all-features --locked
step "cargo test --doc";   cargo test --doc --all-features --locked
step "cargo doc";          RUSTDOCFLAGS="-D warnings" cargo doc --no-deps --all-features --locked --quiet
step "cargo deny check"
if command -v cargo-deny >/dev/null; then cargo deny --locked check; else skip cargo-deny; fi
step "cargo shear"
if command -v cargo-shear >/dev/null; then cargo shear; else skip cargo-shear; fi
step "actionlint"
if command -v actionlint >/dev/null; then actionlint; else skip actionlint; fi
printf '\n\033[1;32mCI green\033[0m\n'
