# Optional Nix development environment (https://devenv.sh): `devenv shell`
# gives the same tools `make setup-all` installs, pinned per project and
# isolated from the rest of the machine. Nothing else in the repository
# needs it; scripts/setup.sh stays the way CI and non-Nix hosts get set up.
# Adapted from https://www.namtao.com/rust-toolkit-2026/ (docs/rust-practices.md).
{ pkgs, ... }:

{
  # Nightly from oxalica's rust-overlay (the `rust-overlay` input in
  # devenv.yaml), with the components rust-toolchain.toml lists.
  languages.rust = {
    enable = true;
    channel = "nightly";
    components = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" "rust-src" ];
  };

  packages = with pkgs; [
    gnumake
    cargo-nextest
    cargo-deny
    cargo-shear
    bacon
    watchexec
    cargo-seek
    cargo-generate
    shellcheck
    actionlint
  ];

  # `watcher`: clippy, then tests, then run, on every save (make watch-run).
  scripts.watcher = {
    exec = ''
      watchexec --clear --exts rs,toml -- \
        "cargo clippy --all-targets --all-features -- -D warnings && cargo nextest run --all-features && cargo run"
    '';
    description = "Re-run clippy, the tests and the binary on every save";
  };

  # Show which dependencies have newer versions each time the shell opens;
  # offline, say so instead of failing the shell.
  enterShell = ''
    echo "Crates ready to update with 'cargo update':"
    cargo update --dry-run || echo "(offline: skipped the update check)"
  '';

  # The same gate as .githooks/pre-commit, installed by devenv. Use one or
  # the other: git ignores .git/hooks once `make hooks` sets core.hooksPath.
  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy = {
      enable = true;
      settings = {
        allFeatures = true;
        denyWarnings = true;
      };
    };
  };
}
