#!/usr/bin/env bash
# Claude Code SessionStart hook (wired in .claude/settings.json).
#
# In a Claude Code on the web session (CLAUDE_CODE_REMOTE=true) the container
# is fresh, so install the toolchain from rust-toolchain.toml and the test
# runner with scripts/setup.sh; its log goes to target/ rather than into
# Claude's context. On a personal machine the tools are the user's business
# and this does nothing. Never fails: a hook error must not cost a session.
set -u
root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0

if [ "${CLAUDE_CODE_REMOTE:-}" != true ]; then
  exit 0
fi

mkdir -p target
if scripts/setup.sh > target/session-setup.log 2>&1; then
  echo "Toolchain ready (scripts/setup.sh; log in target/session-setup.log): $(rustc --version 2>/dev/null)"
else
  echo "scripts/setup.sh failed; see target/session-setup.log, then run make setup."
fi
exit 0
