#!/usr/bin/env bash
# Render the Homebrew cask for one released version on stdout: download the
# four release archives from GitHub, take their sha256, and fill the
# placeholders of .github/homebrew/cask.rb.tmpl. The release workflow pushes
# the result to justanotherspy/homebrew-tap as Casks/<name>.rb (CLAUDE.md
# § Release process).
#
#   scripts/render-cask.sh 0.3.0 > cask.rb
#   scripts/render-cask.sh v0.3.0     the same (a leading v is dropped)
#
# The cask's name, binary and description come from Cargo.toml's `name` and
# `description`; the repository from GITHUB_REPOSITORY, else the `origin`
# remote. Every archive must already be attached to the release: a missing
# one fails the script, and so does a hash that is not 64 hex digits.
# Portable shell only (shasum, not sha256sum: the macOS runner has no
# coreutils).
set -euo pipefail
cd "$(dirname "$0")/.."

version="${1:-}"
if [ -z "$version" ]; then
  echo "usage: scripts/render-cask.sh <version>" >&2
  exit 2
fi
version="${version#v}"

# The first `key = "value"` in Cargo.toml, which is [package]'s.
package_field() {
  sed -n "s/^$1 = \"\\(.*\\)\"\$/\\1/p" Cargo.toml | head -n 1
}
name="$(package_field name)"
desc="$(package_field description)"
repo="${GITHUB_REPOSITORY:-$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')}"
if [ -z "$name" ] || [ -z "$desc" ] || [ -z "$repo" ]; then
  echo "render-cask: need name and description in Cargo.toml and a GitHub repository (got '$name', '$desc', '$repo')" >&2
  exit 1
fi
base="https://github.com/$repo/releases/download/v$version"
template=".github/homebrew/cask.rb.tmpl"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Downloads the archive for one target and prints its sha256. `--retry`
# covers transient errors only; a 404 (asset not attached) fails at once.
sha() {
  local archive="$name-$1.tar.gz" digest
  curl -fsSL --retry 5 -o "$tmp/$archive" "$base/$archive" || {
    echo "render-cask: cannot download $base/$archive" >&2
    return 1
  }
  digest="$(shasum -a 256 "$tmp/$archive" | cut -d' ' -f1)"
  case "$digest" in
    *[!0-9a-f]* | "") echo "render-cask: bad sha256 for $archive: '$digest'" >&2; return 1 ;;
  esac
  if [ "${#digest}" != 64 ]; then
    echo "render-cask: bad sha256 for $archive: '$digest'" >&2
    return 1
  fi
  printf '%s\n' "$digest"
}

# Escapes a value for the replacement side of a sed `s|…|…|`, and for the
# Ruby double-quoted string it lands in.
escape() {
  printf '%s' "$1" | sed -e 's/[\\"#]/\\&/g' -e 's/[|&\\]/\\&/g'
}

# Plain assignments, one per line: `set -e` stops on a failed command
# substitution here, where it would not inside sed's argument list.
sha_x86_64_apple_darwin="$(sha x86_64-apple-darwin)"
sha_aarch64_apple_darwin="$(sha aarch64-apple-darwin)"
sha_x86_64_linux="$(sha x86_64-unknown-linux-gnu)"
sha_aarch64_linux="$(sha aarch64-unknown-linux-gnu)"

rendered="$(sed \
  -e "s|@@VERSION@@|$version|g" \
  -e "s|@@NAME@@|$name|g" \
  -e "s|@@REPO@@|$repo|g" \
  -e "s|@@DESC@@|$(escape "$desc")|g" \
  -e "s|@@SHA_X86_64_APPLE_DARWIN@@|$sha_x86_64_apple_darwin|" \
  -e "s|@@SHA_AARCH64_APPLE_DARWIN@@|$sha_aarch64_apple_darwin|" \
  -e "s|@@SHA_X86_64_LINUX@@|$sha_x86_64_linux|" \
  -e "s|@@SHA_AARCH64_LINUX@@|$sha_aarch64_linux|" \
  "$template")"

# A placeholder the template added but this script does not know would
# otherwise reach the tap as literal text.
if printf '%s\n' "$rendered" | grep -q '@@'; then
  echo "render-cask: unreplaced placeholder in $template:" >&2
  printf '%s\n' "$rendered" | grep '@@' >&2
  exit 1
fi
printf '%s\n' "$rendered"
