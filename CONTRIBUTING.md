# Contributing

## Getting started

```sh
make setup   # nightly toolchain from rust-toolchain.toml, cargo-nextest, shellcheck
make check   # fmt + clippy + tests + doctests: run before every commit
make ci      # everything CI runs
make hooks   # optional: fmt --check + clippy before every commit
make watch   # optional: bacon re-runs clippy on every save (make setup-all)
```

`make help` lists every target.

## Workflow

1. Branch off `main`.
2. Make the change, with tests. Add a line under `## Unreleased` in
   `CHANGELOG.md` when a user would notice it.
3. `make check`, then open a pull request and fill in the template. CI must
   be green; `main` takes pull requests only, with signed commits.

## Commit messages

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, …), which is also
what Renovate writes.

## Style

The lint set is strict: clippy `pedantic` and `nursery`, and no panics
outside tests (`unwrap`, `expect`, indexing, unchecked arithmetic, `as`).
[CLAUDE.md](CLAUDE.md) has the full rules, and
[docs/rust-practices.md](docs/rust-practices.md) the reasons and sources,
including what to write instead of each denied form.

## Reporting bugs and requesting features

Open an issue from one of the [issue templates][issues]. Security issues go
through the [security policy](SECURITY.md) instead.

[issues]: https://github.com/justanotherspy/rust-template/issues/new/choose
