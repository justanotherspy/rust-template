#!/usr/bin/env bash
# Install or update everything the Makefile targets need, on any host.
#
#   scripts/setup.sh          rustup, the nightly toolchain from
#                             rust-toolchain.toml (updated to the latest
#                             nightly, with its components), cargo-nextest
#                             and the shell linter
#   scripts/setup.sh --all    + cargo-deny (make deny), actionlint,
#                             cargo-shear (make shear), bacon (make watch)
#                             and watchexec (make watch-run)
#
# In CI (CI=true) tools are fetched prebuilt instead of compiled.
# Idempotent: re-running only updates what is out of date.
set -euo pipefail
cd "$(dirname "$0")/.."

want_all=0
for arg in "$@"; do
  case "$arg" in
    --all) want_all=1 ;;
    -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "setup: unknown flag $arg" >&2; exit 2 ;;
  esac
done

log() { printf '\n\033[1;36m== %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
in_ci=0
if [ "${CI:-}" = true ]; then in_ci=1; fi
cargo_bin="${CARGO_HOME:-$HOME/.cargo}/bin"
ACTIONLINT_VERSION="v1.7.12"
export PATH="$cargo_bin:$PATH"

# The get.nexte.st platform name: mac (universal), linux, linux-arm.
nextest_platform() {
  case "$(uname -s)/$(uname -m)" in
    Darwin/*) echo mac ;;
    */aarch64 | */arm64) echo linux-arm ;;
    *) echo linux ;;
  esac
}

sudo_cmd=""
if [ "$(id -u)" != 0 ] && have sudo; then sudo_cmd="sudo"; fi

# Installs a package through the host's package manager (brew or apt).
pkg_install() {
  if have brew; then
    brew install "$@"
  elif have apt-get; then
    $sudo_cmd apt-get update -qq
    $sudo_cmd apt-get install -y --no-install-recommends "$@"
  else
    return 1
  fi
}

# Installs a cargo tool: prebuilt through cargo-binstall when it is there,
# compiled with `cargo install --locked` otherwise.
cargo_tool() {
  if have cargo-binstall; then
    cargo binstall --no-confirm --locked "$1"
  else
    cargo install --locked "$1"
  fi
}

# Installs crate <crate> unless its binary <bin> is already on PATH.
cargo_tool_once() {
  if have "$2"; then
    log "$1 present: $("$2" --version 2>&1 | head -n 1)"
  else
    log "$1"
    cargo_tool "$1"
  fi
}

# --- rustup -----------------------------------------------------------------
if ! have rustup; then
  log "installing rustup"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --no-modify-path --default-toolchain none
fi

# --- toolchain: rust-toolchain.toml, then the latest nightly ----------------
channel="$(sed -n 's/^channel *= *"\([^"]*\)".*/\1/p' rust-toolchain.toml)"
log "rustup toolchain install (rust-toolchain.toml: $channel)"
# The no-argument form (rustup >= 1.28) reads rust-toolchain.toml, components
# and profile included.
rustup toolchain install
log "rustup update $channel"
rustup update --no-self-update "$channel"
if ! have cargo || ! have rustc; then
  echo "setup: rustup is installed but cargo/rustc are not on PATH; add $cargo_bin (or your package manager's rustup bin directory) to PATH and re-run." >&2
  exit 1
fi
rustc --version

# --- cargo-nextest ----------------------------------------------------------
if have cargo-nextest; then
  log "cargo-nextest present: $(cargo nextest --version | head -n 1)"
elif [ "$in_ci" = 1 ]; then
  log "cargo-nextest (prebuilt from get.nexte.st)"
  mkdir -p "$cargo_bin"
  curl -LsSf "https://get.nexte.st/latest/$(nextest_platform)" | tar zxf - -C "$cargo_bin"
else
  log "cargo-nextest"
  cargo_tool cargo-nextest
fi

# --- shellcheck (scripts/ci.sh gates on it) ----------------------------------
if have shellcheck; then
  log "shellcheck present: $(shellcheck --version | awk '/^version:/ {print $2}')"
else
  log "shellcheck (package manager)"
  pkg_install shellcheck || echo "setup: shellcheck not installed; ci.sh will skip that step." >&2
fi

# --- optional: cargo-deny, cargo-shear, bacon, watchexec, actionlint --------
if [ "$want_all" = 1 ]; then
  cargo_tool_once cargo-deny cargo-deny
  cargo_tool_once cargo-shear cargo-shear
  cargo_tool_once bacon bacon
  cargo_tool_once watchexec-cli watchexec
  if have actionlint; then
    log "actionlint present: $(actionlint --version | head -n 1)"
  else
    log "actionlint"
    # Homebrew has it; apt does not, so fall back to Go (preinstalled on the
    # GitHub runners) at a pinned version.
    if have brew; then
      brew install actionlint
    elif have go; then
      GOBIN="$cargo_bin" go install "github.com/rhysd/actionlint/cmd/actionlint@$ACTIONLINT_VERSION"
    else
      echo "setup: install actionlint from https://github.com/rhysd/actionlint to lint workflows." >&2
    fi
  fi
fi

log "ready"
printf '  %-10s %s\n' rustc "$(rustc --version)" cargo "$(cargo --version)" nextest "$(cargo nextest --version | head -n 1)"
