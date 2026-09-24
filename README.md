# rust-template

[![CI](https://github.com/justanotherspy/rust-template/actions/workflows/ci.yml/badge.svg)](https://github.com/justanotherspy/rust-template/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A Rust command-line tool.

<!-- TEMPLATE:START -->
## Using this template

This repository is a GitHub [template repository][template-docs] for Rust
command-line tools, set up the way the other `justanotherspy` tools
([garnish], [garlic], [go-template]) are built and shipped:

| Area | What you get |
| --- | --- |
| Toolchain | Rolling **nightly** via `rust-toolchain.toml` (rustfmt, clippy, rust-analyzer, rust-src), edition 2024, installed and updated by `make setup` |
| Code | A clap + color-eyre CLI skeleton (`src/cli.rs`), a pure example module (`src/greet.rs`), unit, doc and end-to-end tests |
| Lints | clippy `pedantic` + `nursery` denied, every panic path denied outside tests, `unsafe` forbidden, nightly-only rustfmt options |
| Tests | cargo-nextest (`.config/nextest.toml`), doctests, rustdoc `-D warnings` |
| Supply chain | cargo-deny (`deny.toml`), Renovate from the shared [`justanotherspy/renovate`][renovate] preset, SHA-pinned actions, zizmor, TruffleHog |
| CI | Linux + macOS on a fresh nightly for every PR and push, plus a weekly run to catch a breaking nightly |
| Release | A signed `vX.Y.Z` tag builds four targets, publishes a GitHub release from `CHANGELOG.md`, and, after your approval, pushes a Homebrew cask to [`justanotherspy/homebrew-tap`][tap] |
| Claude Code | `CLAUDE.md`, the [`justanotherspy/claude-plugins`][plugins] marketplace with `shuck` enabled, a rust-analyzer LSP plugin, and a SessionStart hook that installs the toolchain in web sessions |

### Generate a repository

1. **Use this template → Create a new repository.** Leave *Include all
   branches* off: only the default branch is needed, and branches created
   from a template have unrelated histories, so they cannot be merged back.
   The new repository starts from a single commit.
2. Name it after the tool. The name becomes the crate, the binary and the
   cask, so it must be a valid crate name: ASCII letters, digits, `-`, `_`,
   not starting with a digit.
3. The **Template Cleanup** workflow runs on the first push to `main` and
   opens a pull request that renames `rust-template` / `rust_template` /
   `RUST_TEMPLATE` to your name everywhere outside `.github/workflows/`,
   points `CODEOWNERS` at the new owner, and strips these template-only
   blocks. For it to open the PR, *Settings → Actions → General → Allow
   GitHub Actions to create and approve pull requests* must be on (otherwise
   it pushes the branch and links a compare page). Set a
   `TEMPLATE_CLEANUP_TOKEN` secret (a PAT with `repo` + `workflow`) before
   the first push if you want it to also delete itself and run CI on its PR.
4. In that pull request, set `description` in `Cargo.toml` (it becomes the
   cask's `desc`), delete `.github/workflows/template-cleanup.yml`, and merge.

### After generating: what the template cannot carry

A template copies files, not settings: secrets, environments, rulesets,
branch protection and app installations all start empty in the new
repository. Set these up once:

- **Branch ruleset on `main`**: require a pull request, signed commits, and
  the CI checks (`linux (nightly)`, `macos (nightly)`, `cargo-deny`,
  `actionlint`) to pass.
- **Tag ruleset on `v*`**: only you may create tags, signatures required.
- **`release` environment** with yourself as required reviewer, deployment
  branches/tags limited to `v*` tags, and *allow administrators to bypass*
  off. The release workflow refuses to run without it.
- **Homebrew tap grant**: add `.github/chainguard/<repo>.sts.yaml` to
  [`justanotherspy/homebrew-tap`][tap] trusting
  `repo:justanotherspy/<repo>:environment:release` with `contents: write`
  (copy an existing policy there), and list the cask in the tap's README.
- **Renovate**: make sure the Renovate app is enabled for the new repository;
  `renovate.json` extends the shared preset.
- **Claude Code plugin** (optional): if the tool ships a plugin, add it under
  `plugins/<name>` and register it in [`justanotherspy/claude-plugins`][plugins].

[template-docs]: https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-template-repository
[garnish]: https://github.com/justanotherspy/garnish
[garlic]: https://github.com/justanotherspy/garlic
[go-template]: https://github.com/justanotherspy/go-template
[renovate]: https://github.com/justanotherspy/renovate
[tap]: https://github.com/justanotherspy/homebrew-tap
[plugins]: https://github.com/justanotherspy/claude-plugins
<!-- TEMPLATE:END -->

## Install

With [Homebrew](https://brew.sh) (macOS and Linux):

```sh
brew install --cask justanotherspy/tap/rust-template
```

The cask strips macOS's quarantine flag, since the binaries are not
notarized. If you download a release archive by hand instead and macOS
blocks it:

```sh
xattr -dr com.apple.quarantine "$(command -v rust-template)"
```

From source, with [Rust](https://rustup.rs) installed:

```sh
cargo install --locked --git https://github.com/justanotherspy/rust-template
```

Prebuilt archives for Linux and macOS (x86_64 and aarch64), each with a
`.sha256`, are on the [releases page](https://github.com/justanotherspy/rust-template/releases).

## Usage

```sh
rust-template                     # Hello, world!
rust-template greet Ferris        # Hello, Ferris!
rust-template greet --shout       # HELLO, WORLD!
RUST_TEMPLATE_NAME=Ferris rust-template greet
rust-template --help
```

## Development

```sh
make setup   # rustup + the nightly from rust-toolchain.toml + cargo-nextest + shellcheck
make check   # fmt --check, strict clippy, nextest, doctests
make ci      # everything CI runs, including rustdoc, cargo-deny and actionlint
make help    # every target
```

`make setup-all` also installs `cargo-deny` and `actionlint`. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the workflow and [CLAUDE.md](CLAUDE.md)
for the full conventions.

## Releasing

1. Open a release PR: bump `version` in `Cargo.toml`, rename
   `## Unreleased` in `CHANGELOG.md` to `## X.Y.Z — YYYY-MM-DD`, run
   `make check`, merge.
2. Tag the merged commit with a signed tag whose message is the changelog
   section, and push it:

   ```sh
   git switch main && git pull
   scripts/changelog-section.sh X.Y.Z | git tag -s vX.Y.Z -F -
   git push origin vX.Y.Z
   ```

3. The **Release** workflow verifies the tag, creates a pre-release, builds
   and attaches the four archives, renders and `brew fetch`-checks the cask,
   then **waits for your approval** in the `release` environment. Approve it
   (the run page → *Review deployments*) after reading the rendered cask in
   the render job's log; the cask is pushed to the tap and the release is
   marked *Latest*.

## License

[MIT](LICENSE)
