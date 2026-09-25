# Rust practices: what this project uses, and why

This project's tooling, lints and crate choices follow two write-ups by
Tris Oaten ([No Boilerplate](https://www.youtube.com/@NoBoilerplate)):

- **[Rust]** (namtao.com/rust): the strict clippy set, the test-only
  allowances, a personal standard library of crates, a devenv config, the
  typestate pattern, and how to read function signatures.
- **[My 2026 Rust Toolkit][toolkit]** (namtao.com/rust-toolkit-2026): the
  tools (rustup, cargo, clippy, bacon, nextest, watchexec, cargo-generate,
  devenv), the standard library (color-eyre, itertools, criterion, rayon),
  and the go-to crates (serde, jiff, clap, reqwest, sqlx, and more).

This page maps each recommendation to where it lives in this repository and
explains the reasoning, so you can keep, change or drop it knowingly.
Quotations are from those two pages (spelling lightly corrected). Where this project differs from them,
the [Deviations](#where-this-project-differs-and-why) section says how
and why.

[Rust]: https://www.namtao.com/rust/
[toolkit]: https://www.namtao.com/rust-toolkit-2026/

## At a glance

| Practice | Here | Run it | Source |
| --- | --- | --- | --- |
| Rolling nightly toolchain with rust-analyzer | `rust-toolchain.toml` | `make setup` | [toolkit § Rustup][toolkit] |
| Strict clippy: `pedantic`, `nursery`, no panics | `Cargo.toml` `[lints]` | `make lint` | [Rust § Strict Lints][Rust] |
| Panics allowed in unit tests only | `clippy.toml` | | [Rust § Strict Lints][Rust] |
| Background checking on save | `bacon.toml` | `make watch` | [toolkit § Bacon][toolkit] |
| Clippy, then tests, then run, on save | `Makefile` | `make watch-run` | [toolkit § Watchexec][toolkit] |
| nextest as the test runner | `.config/nextest.toml` | `make test` | [toolkit § cargo-nextest][toolkit] |
| Statistics-driven benchmarks | `benches/`, criterion | `make bench` | [toolkit § Criterion][toolkit] |
| Clippy as a pre-commit hook | `.githooks/pre-commit` | `make hooks` | [toolkit § devenv `git-hooks`][toolkit] |
| Remove unused dependencies | CI `cargo-shear` job | `make shear` | [toolkit § Search & Add][toolkit] |
| See which crates can be updated | | `make outdated` | [toolkit § devenv `enterShell`][toolkit] |
| One-file, per-project dev environment | `devenv.nix`, `devenv.yaml` | `devenv shell` | [toolkit § Devenv][toolkit], [Rust § Rust Devenv][Rust] |
| color-eyre errors, clap derive arguments | `src/main.rs`, `src/cli.rs` | | [toolkit § Color-eyre, Clap][toolkit] |

## Toolchain: rolling nightly

> "While you may stay on the stable version if you have very good reason, I
> have been using nightly since 2020. [...] This is rust, nightly builds are
> REALLY stable!" ([toolkit § Rustup][toolkit])

`rust-toolchain.toml` selects `nightly` with `rustfmt`, `clippy`,
`rust-analyzer` and `rust-src`. Any `cargo` command in this directory uses
it, and `make setup` updates it to the latest nightly. Nightly gives the
newest clippy `nursery` lints, the unstable rustfmt options in
`rustfmt.toml`, and compiler speedups before they reach stable.

What keeps nightly safe here:

- The code uses no `#![feature(...)]`, so it still builds on stable and
  `cargo install --git` works for users who never touch nightly.
- CI installs a fresh nightly on every run, and a weekly scheduled run
  catches a breaking nightly before a pull request does. If one breaks the
  build, pin `channel = "nightly-YYYY-MM-DD"` to the last good date until
  it is fixed upstream (CLAUDE.md § Toolchain).

## Strict lints: learn Rust, never panic

> "These lints do two things: Teach you rust. Stop panics at runtime."
> ([Rust § Strict Lints][Rust])

`Cargo.toml`'s `[lints.clippy]` is the lint set from the source, verbatim:

- **`pedantic`** ("UM, ACTUALLY") and **`nursery`** (newer lints still
  being refined) are denied. They catch unidiomatic code: needless clones,
  missing `#[must_use]`, casts that lose information, overly long
  functions, doc comments missing `# Errors` sections. Read each error's
  explanation link: this is the "teach you Rust" half.
- **Every panic path** is denied: `unwrap_used`, `expect_used`,
  `indexing_slicing`, `arithmetic_side_effects`, `unreachable`,
  `unimplemented`, `unchecked_time_subtraction`, `todo`, `string_slice`,
  `panic_in_result_fn`, `panic`, `exit`, `as_conversions`. A program that
  passes them can still return an error, but it does not crash on a
  surprise `None`, an out-of-range index, an overflowing add or a lossy
  cast. The failure path shows up in the types instead.

This project adds `dbg_macro`, `print_stdout` and `print_stderr` (output
goes through a `&mut impl Write` so commands are testable), forbids
`unsafe_code`, and warns on `missing_docs` and `unreachable_pub`.

What to write instead of the denied forms:

| Denied | Write |
| --- | --- |
| `x.unwrap()`, `x.expect("…")` | `x?`, `x.ok_or_else(…)?`, `x.unwrap_or(…)`, `let Some(v) = x else { … }` |
| `v[i]`, `&s[a..b]` | `v.get(i)`, `s.get(a..b)`, iterators |
| `a + b` on runtime values | `a.checked_add(b)`, `saturating_add`, `wrapping_add` |
| `x as u32` | `u32::from(x)`, `u32::try_from(x)?` |
| `std::process::exit(1)` | return `ExitCode` from `main` |
| `todo!()`, `unimplemented!()` | return an error, or leave the feature out |

### Prototyping stays fast, in tests

> "If you're wondering how to prototype code quickly using `.unwrap()` and
> friends - put them in unit tests, clippy ignores those!"
> ([Rust § Strict Lints][Rust])

`clippy.toml` sets `allow-unwrap-in-tests`, `allow-expect-in-tests`,
`allow-panic-in-tests` and `allow-indexing-slicing-in-tests`, so
`#[cfg(test)]` code may panic freely: a panic is how a test fails.
Integration tests under `tests/` are separate crates, not `#[cfg(test)]`
modules, so they allow those lints with a crate-level `#![allow(…)]`
instead (see `tests/cli.rs`).

For more depth, the source recommends the video *Rust: Don't Panic* and
the article [Your Clippy Config Should Be Stricter][stricter].

[stricter]: https://emschwartz.me/your-clippy-config-should-be-stricter/

## The inner loop: rust-analyzer, bacon, watchexec

> "I recommend running `bacon clippy` in a terminal, watching the excellent
> output and following its advice. Remember, that the first error in your
> file is not always the one to fix - the first error in the COMPILER
> output usually is." ([toolkit § Bacon][toolkit])

- **rust-analyzer** ships as a toolchain component; point your editor's
  LSP at it. (Claude Code uses it through `.claude/skills/rust-lsp`.)
- **[bacon]** re-runs a job on every save and shows the first error at
  the top. `bacon.toml` overrides its `clippy` job to the exact gate CI
  runs (every target, every feature, `-D warnings`), so `make watch` (or
  plain `bacon`) going green means `make lint` will too. Press `t` for
  nextest, `d` for rustdoc, `r` to run the binary, `b` for the benchmarks.
- **[watchexec]** chains commands on save. `make watch-run` runs the
  source's pipeline, "`cargo clippy && cargo test && cargo run`", with
  strict clippy and nextest: `make watch-run ARGS="greet Ferris"`.

`make setup-all` installs both.

[bacon]: https://dystroy.org/bacon/
[watchexec]: https://watchexec.github.io/

## Tests: cargo-nextest

> "Though you can test your code with `cargo test` and doctests with
> `cargo test --doc` [...] your testing will be much more powerful and,
> almost as important, PRETTIER with nextest." ([toolkit § cargo-nextest][toolkit])

`make test` runs [nextest] and then `cargo test --doc` (nextest does not
run doctests). `.config/nextest.toml` sets:

- a **slow-test** timeout (flag at 30 s, kill at 60 s), so a hang fails
  instead of stalling CI;
- a **`serial` test group** with one thread: name a test `…serial…` when it
  touches shared global state (environment variables, the working
  directory) and nextest will not run it alongside another;
- a **`ci` profile** (CI sets `NEXTEST_PROFILE=ci`) that prints a failure's
  output both as it happens and in the summary.

Nextest features to reach for when you need them, all linked from the
source: [retries], [heavy tests][threads-required], [record, replay and
rerun][rerun], [coverage] (`cargo llvm-cov nextest`) and
[mutation testing][mutants] (`cargo mutants`; `mutants.out/` is already
ignored in `.gitignore`).

[nextest]: https://nexte.st/
[retries]: https://nexte.st/docs/features/retries/
[threads-required]: https://nexte.st/docs/configuration/threads-required/
[rerun]: https://nexte.st/docs/features/record-replay-rerun/
[coverage]: https://nexte.st/docs/integrations/test-coverage/
[mutants]: https://nexte.st/docs/integrations/cargo-mutants/

## Benchmarks: criterion

> "`cargo bench`, like `cargo test` has a pluggable backend, and
> `criterion` provides advanced statistics and report generation."
> ([toolkit § Criterion][toolkit])

`benches/greet.rs` benchmarks the example `greeting` function with
[criterion]. Each benchmark runs many times; criterion reports a
confidence interval and whether the change since the last run is
significant. The HTML report is at `target/criterion/report/index.html`.

- `make bench` runs every benchmark. Pass criterion flags with `ARGS`:
  `make bench ARGS="--save-baseline main"`, then on your branch
  `make bench ARGS="--baseline main"` to compare.
- Wrap inputs in `std::hint::black_box` so the optimiser cannot compute
  the answer at compile time.
- Each file in `benches/` needs a `[[bench]]` entry with `harness = false`
  in `Cargo.toml`, since criterion provides its own `main`.
- `make bench` runs `cargo bench --bench '*'`, not a bare `cargo bench`:
  the bare form also runs the lib and binary targets under libtest, which
  rejects criterion's flags.

[criterion]: https://github.com/criterion-rs/criterion.rs

## Dependencies: finding, adding, trimming, updating

> "Before opening your browser and heading to crates.io, or - my favourite -
> lib.rs, to find a package for this or that, try `cargo search`."
> ([toolkit § Search & Add][toolkit])

- **Find:** `cargo search <term>`, or browse [lib.rs]. The source's TUI,
  [cargo-seek], wraps search, add and install (`cargo install cargo-seek`).
- **Inspect before adding:** `cargo info <crate>` shows the licence, MSRV
  and every feature flag, so you enable only what you need.
- **Add:** `cargo add <crate> --features …`. Then `make deny` checks the
  new dependency tree against `deny.toml` (licences, RustSec advisories,
  crates.io-only sources).
- **Trim:** the source's honourable mention, [cargo-shear], finds
  dependencies that `Cargo.toml` declares but no code uses. `make shear`
  runs it locally, and the `cargo-shear` CI job fails a pull request that
  leaves one behind.
- **Update:** `make outdated` is the source's `cargo update -n` (dry run):
  it lists what `cargo update` would change and, with `--verbose`, the
  newer major versions it will not take. Renovate opens the actual update
  pull requests.

[lib.rs]: https://lib.rs
[cargo-seek]: https://crates.io/crates/cargo-seek
[cargo-shear]: https://github.com/Boshen/cargo-shear

## The standard library, and go-to crates

The sources list a personal standard library (crates for nearly every
project) and go-to crates (for particular kinds of project). The template
itself depends only on what its CLI skeleton uses. Add the others when your
project needs them, not in advance: every dependency costs compile time and
supply-chain surface, and `cargo-shear` fails CI on one that goes unused.

| Crate | Job | In this project | Source |
| --- | --- | --- | --- |
| [clap] (derive) | argument parsing | **yes**, `src/cli.rs` | toolkit § Clap |
| [color-eyre] | application errors: `Result`, `.wrap_err()`, colourful reports | **yes**, `src/main.rs` | toolkit § Color-eyre |
| [criterion] | benchmarks | **yes** (dev), `benches/` | toolkit § Criterion |
| [serde] | serialisation (with `serde_json`, `toml`) | when needed | toolkit § Serde |
| [jiff] | dates and times | when needed | toolkit § Jiff |
| [rayon] | data parallelism: `.iter()` → `.par_iter()` | when needed | toolkit § Rayon |
| [itertools] | extra iterator adaptors (`interleave`, `kmerge`, `join`, …) | when needed | toolkit § Itertools |
| [thiserror] | typed errors in a library's public API | when needed | toolkit § Color-eyre (honourable mention) |
| [command-run] | running subprocesses, with results and captured output | when needed | toolkit § Command-run |
| [reqwest] | HTTP client (rustls by default) | when needed | toolkit § Reqwest |
| [sqlx] | compile-time-checked SQL | when needed | toolkit § SQLx |
| [utoipa] | OpenAPI docs generated from types | when needed | toolkit § Utoipa |
| [leptos], [dioxus], [tauri] | web frontend; full-stack/desktop/mobile UI; native webview shell | when needed | toolkit § Leptos, Dioxus |

Some notes on these:

- **color-eyre for applications, thiserror for libraries.** An application
  mostly reports errors, so one `eyre::Report` with context is enough. A
  library's callers match on errors, so they need a typed `enum`. This
  crate is both: `src/lib.rs` is internal to the binary, so it uses eyre
  too. Split out a public library and its errors should become thiserror
  types.
- **Parse arguments into types.** "It's argparse, not argvalidate. Do it
  once, and, ideally, let clap do it for you." Parse into enums, paths and
  numbers at the edge, in `src/cli.rs`, so the logic below never
  re-validates strings.
- **Rayon before async.** "Rayon is the simplest parallelism library
  you'll ever use, try it before you reach for heavyweight async
  frameworks." For CPU-bound work, build the logic as an iterator pipeline
  and parallelise by changing `.iter()` to `.par_iter()`. Reach for an
  async runtime only for I/O concurrency.
- **jiff, not chrono.** The [Rust] page lists chrono; the 2026
  toolkit moved to jiff ("encourages you to jump into the pit of success")
  and keeps chrono as the honourable mention. This project follows the
  newer advice.

[clap]: https://docs.rs/clap
[color-eyre]: https://docs.rs/color-eyre
[serde]: https://serde.rs
[jiff]: https://docs.rs/jiff
[rayon]: https://docs.rs/rayon
[itertools]: https://docs.rs/itertools
[thiserror]: https://docs.rs/thiserror
[command-run]: https://docs.rs/command-run
[reqwest]: https://docs.rs/reqwest
[sqlx]: https://docs.rs/sqlx
[utoipa]: https://docs.rs/utoipa
[leptos]: https://leptos.dev
[dioxus]: https://dioxuslabs.com
[tauri]: https://tauri.app

## Design patterns

### Typestate: make invalid states unrepresentable

> "The typestate pattern is an API design pattern that encodes information
> about an object's run-time state in its compile-time type."
> ([Rust § Typestate Pattern][Rust])

Put the state in a type parameter and give each state its own `impl`
block. A transition consumes `self` and returns the next state, so calling
a method in the wrong state is a compile error rather than a runtime check.
It works well alongside the no-panic lints: the `unreachable!()` you might
otherwise write for "can't happen in this state" never needs to exist.

```rust
use std::marker::PhantomData;

// The states: zero-sized types that exist only at compile time.
pub struct Red;
pub struct Green;
pub struct Yellow;

// The set of valid states.
pub trait SignalState {}
impl SignalState for Red {}
impl SignalState for Green {}
impl SignalState for Yellow {}

// The state is a type parameter, not a field.
pub struct TrafficSignal<S: SignalState> {
    name: String,
    state: PhantomData<S>,
}

// Methods on every state.
impl<S: SignalState> TrafficSignal<S> {
    pub fn name(&self) -> &str {
        &self.name
    }

    // Consumes `self`, so the old state cannot be used again.
    fn transition<T: SignalState>(self) -> TrafficSignal<T> {
        TrafficSignal { name: self.name, state: PhantomData }
    }
}

// A new signal starts at red, and red can only turn green.
impl TrafficSignal<Red> {
    pub fn new(name: impl Into<String>) -> Self {
        Self { name: name.into(), state: PhantomData }
    }

    pub fn go(self) -> TrafficSignal<Green> {
        self.transition()
    }
}

impl TrafficSignal<Green> {
    pub fn slow(self) -> TrafficSignal<Yellow> {
        self.transition()
    }
}

impl TrafficSignal<Yellow> {
    pub fn stop(self) -> TrafficSignal<Red> {
        self.transition()
    }
}

fn main() {
    let signal = TrafficSignal::new("Main St").go().slow().stop();
    assert_eq!(signal.name(), "Main St");

    // TrafficSignal::new("Main St").slow();
    // error[E0599]: no method named `slow` found for struct `TrafficSignal<Red>`
}
```

Use it for builders with required steps, protocol handshakes, and
anything that is opened, used and closed. The source keeps a complete
working example at [0atman/typestate-template][typestate].

[typestate]: https://github.com/0atman/typestate-template

### Reading function signatures: bounds and `where`

> "Rust Function Signatures are complex, but they can be understood through
> thorougher thought though." ([Rust § Rust Function Signatures][Rust])

A bound inline and the same bound in a `where` clause mean the same thing:

```rust
fn walk_pet<W: Walk>(pet: &mut W) {
    pet.walk();
}

// is the same as

fn walk_pet<W>(pet: &mut W)
where
    W: Walk,
{
    pet.walk();
}
```

Keep short bounds inline. Move them to `where` when there are several, or
when they involve associated types, so the parameter list stays readable.
The source points to pretzelhammer's
[Tour of Rust's Standard Library Traits][traits] for the traits these
bounds use.

[traits]: https://github.com/pretzelhammer/rust-blog/blob/master/posts/tour-of-rusts-standard-library-traits.md

### Iterator pipelines

> "Ergonomic Rust programs are often built around data that is mutated by
> iterators in a pipeline." ([toolkit § Itertools][toolkit])

Prefer `map` / `filter` / `fold` chains to index loops. They avoid the
`indexing_slicing` lint by construction, they read as a description of the
data flow, and they are one `.par_iter()` away from running in parallel
with rayon. Note the source's own erratum: itertools' adaptors are *not*
all guaranteed zero-cost.

## Environment: devenv and git hooks

> "Look, you don't HAVE to use devenv [...] But isn't it COOL that you get
> all this in a SINGLE config file that you can check in to your project's
> repo, and share with your colleagues!?" ([toolkit § Devenv][toolkit])

`devenv.nix` and `devenv.yaml` are the source's [devenv] configuration,
adapted to this project: nightly Rust from [oxalica's rust-overlay], the
tools `make setup-all` installs, the `watcher` script, an update check on
entering the shell, and rustfmt and clippy git hooks. It is **optional**.
`scripts/setup.sh` stays how CI and non-Nix machines get their tools, and
nothing else in the repository depends on devenv. Install devenv, then run
`devenv shell`. If you do not use Nix, delete both files.

Without devenv, `make hooks` points git at `.githooks/`, whose
`pre-commit` runs `cargo fmt --check` and the strict clippy gate: the same
check as the source's `git-hooks.hooks.clippy`. It leaves out the tests so
that it stays fast enough to keep on. Pick one hook mechanism: once
`core.hooksPath` is set, git ignores the hooks devenv installs.

[devenv]: https://devenv.sh
[oxalica's rust-overlay]: https://github.com/oxalica/rust-overlay

## Editors

The source uses Neovim with [LazyVim](https://www.lazyvim.org), and names
Helix, VS Code and Zed as good alternatives, all with vim keybindings. Any
of them works here: they all speak LSP to rust-analyzer, and
`.editorconfig` covers indentation and line endings.

## Where this project differs, and why

| Source says | This project | Why |
| --- | --- | --- |
| `rustup default nightly` | `rust-toolchain.toml` picks nightly per project | A clone builds with the right toolchain without changing your global default; CI reads the same file |
| Lint set as listed | The same set, plus `dbg_macro`, `print_stdout`, `print_stderr`, `unsafe_code = "forbid"`, `missing_docs` | Output goes through a writer so it can be tested; docs are enforced |
| Standard library in every project | Only what the code uses | cargo-shear and cargo-deny keep the dependency graph honest; add crates as they are needed |
| chrono (Rust page) | jiff | The 2026 toolkit prefers jiff |
| devenv for everything | `scripts/setup.sh` (`make setup`), devenv optional | Works on any host and in CI without Nix |
| `cargo generate` templates | a GitHub template repository | Generated repositories are renamed by the Template Cleanup workflow instead of by Liquid placeholders, so the template itself builds and passes CI |
| Nextest retries available | `retries = 0` | A test that passes on retry is a bug to fix, not to hide |
