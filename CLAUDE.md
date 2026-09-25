# CLAUDE.md — working rules for rust-template

rust-template is a Rust command-line tool. This file is the durable memory of
*how to work on this codebase*: read it before changing anything. `README.md`
is what a user needs; `CHANGELOG.md` is what changed for them.

<!-- TEMPLATE:START -->
## This repository is the template

`justanotherspy/rust-template` is a GitHub template repository. A repository
generated from it is renamed by `.github/workflows/template-cleanup.yml`,
which rewrites `justanotherspy/rust-template`, `rust-template`,
`rust_template` and `RUST_TEMPLATE` in every text file **outside
`.github/workflows/`** (an Actions token may not push workflow changes) and
deletes the `TEMPLATE:START`/`TEMPLATE:END` blocks. So, when editing the
template:

- **Nothing under `.github/workflows/` may name the project.** Workflows read
  the binary name from `Cargo.toml` and the tap identity from
  `github.event.repository.name`. The only exceptions are the two guards that
  compare against the template itself (`release.yml`'s `verify` and the
  cleanup job), which must keep naming it.
- **Every name a generated repository needs changed is spelled one of those
  four ways**, so the rewrite reaches it (the env prefix `RUST_TEMPLATE_NAME`,
  `env!("CARGO_BIN_EXE_rust-template")`, the issue templates). A new file
  path that carries the name would need a `git mv` step in the cleanup; avoid
  one (the cask template is `cask.rb.tmpl` for that reason).
- **Template-only prose goes between the markers**, one block per spot, the
  markers on lines of their own.
- The template never releases: `release.yml` skips itself here.
<!-- TEMPLATE:END -->

## Documents (which file owns what)

| file | owns |
|---|---|
| `CLAUDE.md` | how to build this project: protocol, toolchain, style, release |
| `README.md` | install, usage, development, releasing, for a human |
| `CHANGELOG.md` | user-visible changes per release; a release's section is its tag message and release notes |
| `CONTRIBUTING.md`, `SECURITY.md` | contributor workflow; vulnerability reporting and hardening |
| `docs/rust-practices.md` | why each tool, lint, crate and pattern is here, citing the namtao.com write-ups it follows |
| `rust-toolchain.toml`, `rustfmt.toml`, `clippy.toml`, `.config/nextest.toml`, `deny.toml` | toolchain, formatting, lint, test runner and supply-chain policy |
| `bacon.toml`, `.githooks/pre-commit`, `devenv.nix`, `devenv.yaml` | the inner loop: watch jobs (`make watch`), the opt-in commit hook (`make hooks`), the optional Nix environment |
| `benches/` | criterion benchmarks (`make bench`) |
| `scripts/setup.sh` | installs the prerequisites on any host (`make setup`) |
| `scripts/ci.sh` | the local CI gate (`make ci`) |
| `scripts/changelog-section.sh`, `scripts/render-cask.sh`, `.github/homebrew/cask.rb.tmpl`, `.github/workflows/release.yml` | the release pipeline (§ Release process) |
| `.claude/settings.json`, `.claude/hooks/session-start.sh`, `.claude/skills/rust-lsp/` | Claude Code: plugins, permissions, the web-session setup hook, rust-analyzer |

## Session protocol

1. Start from the latest `main` on a branch; `main` is protected (pull
   requests only, signed commits, CI must pass). Merge only when the user
   asks.
2. Work in small commits (Conventional Commits: `feat:`, `fix:`, `docs:`,
   `chore:`, …). Run `make check` before every commit; if a tool is missing,
   `make setup` (idempotent). Never leave the tree red.
3. Every commit and tag is signed. If signing fails, stop and report it;
   never `--no-gpg-sign`.
4. Push early and open the pull request as a draft. `shuck` (enabled in
   `.claude/settings.json`) reports CI failures on it as they happen: act on
   them, never poll CI in a shell.
5. For a user-visible change, add a line under `## Unreleased` in
   `CHANGELOG.md`, and update `README.md` when a user would need to know.
6. For every real bug found, add a test that fails without the fix.
7. Stop and ask when a decision is the user's: a new dependency, a
   behaviour nothing specifies, a change of scope.
8. Use the rust-analyzer LSP tools (`.claude/skills/rust-lsp`) when
   available: diagnostics after edits, find-references before renaming or
   changing a signature.

## Toolchain

- **Rolling nightly** via `rust-toolchain.toml` (with `rustfmt`, `clippy`,
  `rust-analyzer`, `rust-src`). `make setup` installs it and updates it to
  the latest nightly, plus `cargo-nextest` and `shellcheck`;
  `make setup-all` adds `cargo-deny`, `actionlint`, `cargo-shear`, `bacon`
  and `watchexec`.
- Nightly is what lets `rustfmt.toml` use `imports_granularity` and
  `group_imports`, and what clippy's newest `nursery` lints need. The code
  itself uses no `#![feature]`; keep it that way unless the user agrees, so
  `cargo install --git` works on stable too.
- **CI installs a fresh nightly; a session's may be days older**, so
  `make check` can pass on code CI rejects. When CI is red on a lint and the
  tree is green here, `rustup update nightly` first, then reproduce with one
  `cargo clippy --all-targets`.
- When a new nightly breaks the build, pin `channel = "nightly-YYYY-MM-DD"`
  to the last good date, say so here, and unpin once it is fixed upstream.
  The weekly scheduled CI run exists to catch this before a pull request
  does.
- Edition 2024. `cargo nextest run` for tests (`cargo test` runs the same
  suites without nextest's grouping), `cargo test --doc` for doctests.

## Commands

```
make setup      # nightly toolchain + cargo-nextest + shellcheck (setup-all: + cargo-deny, actionlint, cargo-shear, bacon, watchexec)
make check      # fmt --check + clippy -D warnings + nextest + doctests
make ci         # scripts/ci.sh: check + shellcheck + rustdoc -D warnings + cargo-deny + cargo-shear + actionlint
make lint | fmt | test | doc | deny | shear | bench | outdated | build | release | run ARGS=… | install | clean
make watch      # bacon: strict clippy on every save (humans; not for agents, it never exits)
make hooks      # opt in to .githooks/pre-commit (fmt --check + clippy)
```

CI (`.github/workflows/ci.yml`) runs `scripts/ci.sh` on Linux, `make check`
on macOS, cargo-deny, cargo-shear and actionlint as their own jobs, on every
pull request, push to `main`, and weekly. `zizmor.yml` audits the workflows
and `secret-scan.yml` runs TruffleHog. **Every action is pinned to a full commit
SHA** with a `# vX.Y.Z` comment (Renovate bumps both); never a floating tag
or branch. A checkout that does not push sets `persist-credentials: false`.

## Style: strict lints, never panic

`Cargo.toml` denies `clippy::pedantic`, `clippy::nursery` and every panic
path (`unwrap_used`, `expect_used`, `indexing_slicing`,
`arithmetic_side_effects`, `unreachable`, `unimplemented`,
`unchecked_time_subtraction`, `todo`, `string_slice`, `panic_in_result_fn`,
`panic`, `exit`, `as_conversions`), plus `dbg_macro`, `print_stdout` and
`print_stderr`. `unsafe_code` is forbidden. `clippy.toml` allows
unwrap/expect/panic/indexing in unit tests only.

- Never `unwrap()`/`expect()` outside `#[cfg(test)]`: use `?`, `unwrap_or`,
  `map_or`, `ok_or_else`, `let … else`.
- Never index: `v[i]` → `v.get(i)`; never slice a string by byte range.
- Never `as`: `u32::from(x)`, `usize::try_from(x)?`, `f64::from(x)`.
- Arithmetic on non-constant operands is `checked_*`, `saturating_*` or
  `wrapping_*`.
- Output goes through a `&mut impl Write` handed down from `main`, never
  `println!`, so every command is testable in-process (see `cli::run`).
- `main` returns `color_eyre::Result<ExitCode>`; errors carry context
  (`.wrap_err(…)`). A usage error exits 2 (clap's convention).
- `#[allow(clippy::…)]` only on the item that needs it, with a one-line
  justification comment above it. Integration tests under `tests/` are not
  `#[cfg(test)]`, so they carry a crate-level `#![allow(…)]` with that
  comment.
- Prefer combinators and data-in/data-out functions; keep I/O at the edge
  (`main.rs`, `cli.rs`) and logic in pure modules. Iterator pipelines over
  index loops: they satisfy `indexing_slicing` by construction and become
  parallel with rayon's `.par_iter()`.
- Parse, don't validate: clap turns arguments into typed values in
  `cli.rs`; the logic below never re-checks strings.
- When a value has states with different valid operations, encode the
  state in the type (typestate: a `PhantomData<S>` parameter, one `impl`
  per state, transitions consume `self`) instead of checking at run time.
- Bounds inline when short; a `where` clause when there are several or
  they name associated types.
- Rationale and sources for all of the above: `docs/rust-practices.md`.
- Shell scripts pass `shellcheck` and stay portable across GNU and BSD
  userlands (the macOS runner has no GNU sed/awk extensions, and no
  `sha256sum`: use `shasum -a 256`).

## Comments and documentation

- Every file has a `//!` module doc saying what it owns; every `pub` item a
  `///` doc (`missing_docs` enforces it). Docs say *what* and *why*, follow
  rustdoc conventions (`# Errors`, `# Panics`, intra-doc links), and keep the
  first paragraph short (clippy checks it).
- Inline `//` comments are for the non-obvious only: an invariant, a
  workaround, a subtle ordering. No narration, no "changed X" notes, no
  commented-out code.

## Crates

The chosen crate for each job; do not add an alternative, and ask before
adding any new dependency.

| crate | job |
|---|---|
| clap (derive, env) | argument parsing |
| color-eyre | error type (`Result`, `eyre!`, `.wrap_err()`) and error reports; installed once in `main` |
| serde + serde_json / toml | JSON / TOML, when needed |
| jiff | date and time, when needed (not chrono) |
| rayon | data parallelism, when needed (not tokio for CPU work) |
| itertools | iterator adaptors beyond std, when needed |
| thiserror | typed errors in a public library API, when needed (applications stay on color-eyre) |
| criterion (dev) | benchmarks in `benches/`, each a `[[bench]]` with `harness = false` |
| tempfile (dev) | temporary directories in tests |

`docs/rust-practices.md` lists the go-to crates for other kinds of project
(reqwest, sqlx, utoipa, command-run, leptos, dioxus); they are still new
dependencies, so ask first. `cargo-shear` (CI) fails on a declared
dependency no code uses.

`cargo deny check` enforces licences (`deny.toml`'s allow-list), RustSec
advisories and crates.io as the only source. A new licence goes on the list
deliberately; an advisory is ignored only with its id and a reason.

## Release process

A release is a signed `vX.Y.Z` tag on `main`. `.github/workflows/release.yml`
does the rest and stops once, before the Homebrew cask is published, for the
maintainer's approval.

1. **Release PR** (`release/X.Y.Z`): bump `version` in `Cargo.toml`
   (`make check` updates `Cargo.lock`), rename `## Unreleased` in
   `CHANGELOG.md` to `## X.Y.Z — YYYY-MM-DD`, merge.
2. **Tag** the merged commit; the tag message is the changelog section:
   ```
   git switch main && git pull
   scripts/changelog-section.sh X.Y.Z | git tag -s vX.Y.Z -F -
   git push origin vX.Y.Z
   ```
3. **The workflow**: `verify` (the tag names the crate version, sits on
   `main`, has its changelog section, no `## Unreleased` left; the `release`
   environment exists with a required reviewer) → `release` (a GitHub
   pre-release, notes from the changelog) → `build` (`<name>-<target>.tar.gz`
   plus `.sha256` for x86_64/aarch64 Linux and macOS, no build cache) →
   `render` (`scripts/render-cask.sh` fills `.github/homebrew/cask.rb.tmpl`,
   prints it, `brew fetch`-checks it, keeps it as the `cask` artifact) →
   **`publish` waits in the `release` environment for approval**, then pushes
   `Casks/<name>.rb` to `justanotherspy/homebrew-tap` with a short-lived
   octo-sts token → `promote` marks the release *Latest*.
   A failed job or rejected approval leaves a pre-release with binaries and
   no cask. Re-run failed jobs only for a settings or transient failure;
   anything needing a code change is a new version (a tag is never moved).
4. **Repository state** the workflow needs (settings, not files; a template
   cannot carry them): the `release` environment with a required reviewer,
   deployments limited to `v*` tags; a tag ruleset on `v*` with required
   signatures; and in the tap, `.github/chainguard/<repo>.sts.yaml` trusting
   `repo:justanotherspy/<repo>:environment:release` with `contents: write`.

**The cask template is declarative, not Ruby.** `postflight_steps` (not a
`postflight` block) takes a fixed vocabulary: `run`, not `system_command`;
`on_macos`, not `if OS.mac?`. Ruby interpolation does not run inside it, so
the staged binary is `"{{staged_path}}/<name>"`, a Homebrew install-step
token. `url … verified:` is deprecated: use a bare `url`. Homebrew 7 raises
on deprecated stanzas under `HOMEBREW_DEVELOPER`, so these are load-bearing.
`brew fetch` only downloads and checksums; check the quarantine strip by hand
at the first release's approval gate: download the `cask` artifact on a Mac,
`brew install --cask ./<name>.rb`, then
`xattr -p com.apple.quarantine "$(brew --prefix)/bin/<name>"` must say
*No such xattr*.

## Claude Code setup

- `.claude/settings.json` registers the `justanotherspy/claude-plugins`
  marketplace and enables `shuck@justanotherspy` (a background monitor on
  this branch's pull request: CI failures with their failing step logs,
  review comments, stale action pins). Enable more from that marketplace
  there, not per user.
- `.claude/hooks/session-start.sh` runs `scripts/setup.sh` in Claude Code on
  the web (`CLAUDE_CODE_REMOTE=true`) and does nothing elsewhere; it never
  fails the session.
- `.claude/skills/rust-lsp/` is a skills-directory plugin wiring
  rust-analyzer (the toolchain component) into Claude Code with clippy as the
  check command. Run `/reload-plugins` after editing it.
