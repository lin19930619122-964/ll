#!/usr/bin/env bash
set -euo pipefail

# Repair common local-state and IPC problems that can prevent Codex Desktop
# and Codex CLI from starting, resuming, or sharing a session.
#
# The script is conservative: it only touches Codex-owned directories and stale
# lock/socket files in the current user's home, XDG runtime, and platform app
# support/cache locations.

log() { printf '[codex-session-fix] %s\n' "$*"; }
warn() { printf '[codex-session-fix] warning: %s\n' "$*" >&2; }

require_dir() {
  local dir="$1"
  local mode="${2:-}"

  if [[ -z "$dir" ]]; then
    return 0
  fi

  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    log "created $dir"
  fi

  if [[ -n "$mode" ]]; then
    chmod "$mode" "$dir" 2>/dev/null || warn "could not set permissions on $dir"
  elif [[ ! -w "$dir" ]]; then
    chmod u+rwx "$dir" 2>/dev/null || warn "could not make $dir writable"
  fi
}

is_process_alive() {
  local pid="$1"
  [[ "$pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

remove_stale_locks() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  while IFS= read -r -d '' lock; do
    local pid_file="${lock}.pid"
    if [[ -f "$pid_file" ]] && is_process_alive "$(cat "$pid_file" 2>/dev/null)"; then
      continue
    fi

    # Treat locks older than one day as stale. Newer locks may belong to a running app.
    if [[ $(find "$lock" -mtime +0 -print 2>/dev/null) ]]; then
      rm -f "$lock" "$pid_file"
      log "removed stale lock $lock"
    fi
  done < <(find "$dir" -type f \( -name '*.lock' -o -name 'LOCK' \) -print0 2>/dev/null)
}

remove_stale_sockets() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0

  while IFS= read -r -d '' socket; do
    # Unix sockets cannot be reused after the owning process exits. If a Codex
    # socket is older than one day, assume it is stale and remove it.
    if [[ $(find "$socket" -mtime +0 -print 2>/dev/null) ]]; then
      rm -f "$socket"
      log "removed stale socket $socket"
    fi
  done < <(find "$dir" -type s \( -iname '*codex*' -o -iname '*openai*' \) -print0 2>/dev/null)
}

platform_dirs() {
  local xdg_config="$1"
  local xdg_cache="$2"
  local xdg_state="$3"

  printf '%s\0' \
    "$HOME/.codex" \
    "$xdg_config/codex" \
    "$xdg_config/Codex" \
    "$xdg_cache/codex" \
    "$xdg_cache/Codex" \
    "$xdg_state/codex" \
    "$xdg_state/Codex"

  case "$(uname -s)" in
    Darwin)
      printf '%s\0' \
        "$HOME/Library/Application Support/Codex" \
        "$HOME/Library/Caches/Codex" \
        "$HOME/Library/Saved Application State/com.openai.codex.savedState"
      ;;
    Linux)
      printf '%s\0' \
        "$HOME/.local/share/codex" \
        "$HOME/.local/share/Codex"
      ;;
  esac
}

network_preflight() {
  if [[ "${CODEX_SKIP_NETWORK_CHECK:-}" == "1" ]]; then
    log 'skipped ChatGPT/Codex network preflight because CODEX_SKIP_NETWORK_CHECK=1'
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    warn 'curl is not installed; skipping ChatGPT/Codex network preflight.'
    return 0
  fi

  local proxy_vars=()
  for name in HTTPS_PROXY https_proxy HTTP_PROXY http_proxy ALL_PROXY all_proxy NO_PROXY no_proxy; do
    if [[ -n "${!name:-}" ]]; then
      proxy_vars+=("$name")
    fi
  done
  if (( ${#proxy_vars[@]} > 0 )); then
    warn "proxy environment variables are set (${proxy_vars[*]}); a broken proxy can cause Codex stream disconnects."
  fi

  local urls=(
    'https://chatgpt.com/'
    'https://chatgpt.com/backend-api/codex/response'
  )

  local url
  for url in "${urls[@]}"; do
    if curl --silent --show-error --location --head --connect-timeout 10 --max-time 20 "$url" >/dev/null; then
      log "network preflight reached $url"
    else
      warn "could not reach $url; this can cause 'stream disconnected before completion' in Codex Desktop."
    fi
  done
}

main() {
  if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
    warn 'HOME is not set to a valid directory; Codex Desktop needs a writable home directory.'
    exit 1
  fi

  local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local xdg_cache="${XDG_CACHE_HOME:-$HOME/.cache}"
  local xdg_state="${XDG_STATE_HOME:-$HOME/.local/state}"
  local xdg_runtime="${XDG_RUNTIME_DIR:-}"

  require_dir "$xdg_config"
  require_dir "$xdg_cache"
  require_dir "$xdg_state"

  if [[ -n "$xdg_runtime" ]]; then
    require_dir "$xdg_runtime" 700
    remove_stale_sockets "$xdg_runtime"
  fi

  network_preflight

  while IFS= read -r -d '' dir; do
    require_dir "$dir"
    remove_stale_locks "$dir"
    remove_stale_sockets "$dir"
  done < <(platform_dirs "$xdg_config" "$xdg_cache" "$xdg_state")

  log 'Codex Desktop and CLI session directories are present and writable.'
  log 'If either app is open, quit it fully and start a new session.'
}

main "$@"
