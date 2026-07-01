#!/usr/bin/env bash
set -euo pipefail

# Reset Codex Desktop app-local state when the web app works but the desktop app
# cannot maintain a Codex session stream. The reset is reversible: matching app
# directories/files are moved into a timestamped backup directory instead of
# being deleted.

log() { printf '[codex-reset] %s\n' "$*"; }
warn() { printf '[codex-reset] warning: %s\n' "$*" >&2; }

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

backup_root="${CODEX_DESKTOP_BACKUP_DIR:-$HOME/.codex-desktop-backups/$(date +%Y%m%d-%H%M%S)}"

quit_desktop() {
  case "$(uname -s)" in
    Darwin)
      osascript -e 'quit app "Codex"' >/dev/null 2>&1 || true
      osascript -e 'quit app "OpenAI Codex"' >/dev/null 2>&1 || true
      ;;
    Linux)
      pkill -x codex-desktop >/dev/null 2>&1 || true
      pkill -x openai-codex >/dev/null 2>&1 || true
      pkill -x Codex >/dev/null 2>&1 || true
      ;;
  esac
}

candidate_paths() {
  local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local xdg_cache="${XDG_CACHE_HOME:-$HOME/.cache}"
  local xdg_state="${XDG_STATE_HOME:-$HOME/.local/state}"
  local xdg_data="${XDG_DATA_HOME:-$HOME/.local/share}"

  printf '%s\0' \
    "$HOME/.codex" \
    "$xdg_config/codex" \
    "$xdg_config/Codex" \
    "$xdg_cache/codex" \
    "$xdg_cache/Codex" \
    "$xdg_state/codex" \
    "$xdg_state/Codex" \
    "$xdg_data/codex" \
    "$xdg_data/Codex"

  case "$(uname -s)" in
    Darwin)
      printf '%s\0' \
        "$HOME/Library/Application Support/Codex" \
        "$HOME/Library/Application Support/OpenAI Codex" \
        "$HOME/Library/Caches/Codex" \
        "$HOME/Library/Caches/OpenAI Codex" \
        "$HOME/Library/HTTPStorages/Codex" \
        "$HOME/Library/HTTPStorages/OpenAI Codex" \
        "$HOME/Library/Saved Application State/com.openai.codex.savedState" \
        "$HOME/Library/Preferences/com.openai.codex.plist"
      ;;
  esac
}

backup_path() {
  local path="$1"
  local relative="${path#$HOME/}"
  local destination="$backup_root/$relative"

  if [[ ! -e "$path" && ! -L "$path" ]]; then
    return 0
  fi

  if [[ "$DRY_RUN" == 1 ]]; then
    log "would move $path -> $destination"
    return 0
  fi

  mkdir -p "$(dirname "$destination")"
  mv "$path" "$destination"
  log "moved $path -> $destination"
}

main() {
  if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
    warn 'HOME is not set to a valid directory.'
    exit 1
  fi

  log 'quitting Codex Desktop if it is running'
  quit_desktop

  while IFS= read -r -d '' path; do
    backup_path "$path"
  done < <(candidate_paths)

  if [[ "$DRY_RUN" == 1 ]]; then
    log 'dry run complete; no files were moved.'
  else
    log "reset complete; backup is at $backup_root"
    log 'start Codex Desktop again and sign in if prompted.'
  fi
}

main "$@"
