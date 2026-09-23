# Security Policy

## Supported versions

Only the latest release is supported. Please upgrade before reporting an
issue.

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report privately through GitHub's [security advisories][advisories] ("Report a
vulnerability" on the **Security** tab), or contact the maintainers listed in
[CODEOWNERS](.github/CODEOWNERS).

[advisories]: https://github.com/justanotherspy/rust-template/security/advisories/new

Please include a description of the issue and its impact, steps to reproduce
or a proof of concept, and the affected version(s).

## Hardening in place

- `unsafe` code is forbidden (`#![forbid(unsafe_code)]` via `[lints.rust]`)
  and clippy denies every panic path outside tests.
- `cargo-deny` checks every dependency against the RustSec advisory database,
  an allow-list of licences, and crates.io as the only source, on every pull
  request.
- Dependencies and GitHub Actions are kept current by Renovate; every action
  is pinned to a full commit SHA. zizmor audits the workflows, TruffleHog
  scans for committed secrets.
- Releases are built from a signed tag on `main` without a build cache,
  published with a SHA-256 per archive, and the Homebrew cask is pushed only
  after a required reviewer approves it, with a short-lived token scoped to
  the tap.
