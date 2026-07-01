#!/usr/bin/env bash
set -euo pipefail

# One-command recovery for Codex Desktop session stream failures.
# It resets Desktop app state, repairs local session files, then starts Desktop
# with a clean network environment for ChatGPT/OpenAI endpoints.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[codex-repair] %s\n' "$*"; }

log 'resetting Codex Desktop app state into a reversible backup'
"$script_dir/reset-codex-desktop-app-state.sh"

log 'repairing local Codex session directories, locks, and sockets'
CODEX_SKIP_NETWORK_CHECK="${CODEX_SKIP_NETWORK_CHECK:-1}" "$script_dir/fix-codex-desktop-session.sh"

if [[ "${CODEX_REPAIR_SKIP_LAUNCH:-}" == "1" ]]; then
  log 'skipping Desktop launch because CODEX_REPAIR_SKIP_LAUNCH=1'
else
  log 'starting Codex Desktop with OpenAI/ChatGPT proxy bypass'
  "$script_dir/launch-codex-desktop-clean-network.sh"
fi

log 'done; sign in again if prompted, then start a new Codex session.'
