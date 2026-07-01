#!/usr/bin/env bash
set -euo pipefail

# Launch Codex Desktop with a clean network environment for OpenAI/ChatGPT
# endpoints. This directly addresses failures like:
#   stream disconnected before completion: error sending request for url
#   https://chatgpt.com/backend-api/codex/response
# when they are caused by a broken proxy/VPN CONNECT path.

log() { printf '[codex-launch] %s\n' "$*"; }
fail() { printf '[codex-launch] error: %s\n' "$*" >&2; exit 1; }

OPENAI_NO_PROXY='chatgpt.com,.chatgpt.com,openai.com,.openai.com,oaistatic.com,.oaistatic.com,oaiusercontent.com,.oaiusercontent.com'

build_env() {
  env \
    -u HTTPS_PROXY -u https_proxy \
    -u HTTP_PROXY -u http_proxy \
    -u ALL_PROXY -u all_proxy \
    NO_PROXY="${NO_PROXY:+$NO_PROXY,}$OPENAI_NO_PROXY" \
    no_proxy="${no_proxy:+$no_proxy,}$OPENAI_NO_PROXY" \
    "$@"
}

launch_macos() {
  local app_path=''
  for candidate in \
    '/Applications/Codex.app' \
    "$HOME/Applications/Codex.app" \
    '/Applications/OpenAI Codex.app' \
    "$HOME/Applications/OpenAI Codex.app"; do
    if [[ -d "$candidate" ]]; then
      app_path="$candidate"
      break
    fi
  done

  if [[ -z "$app_path" ]]; then
    fail 'Codex Desktop app was not found in /Applications or ~/Applications.'
  fi

  log "launching $app_path with OpenAI/ChatGPT proxy bypass"
  build_env open -n "$app_path"
}

launch_linux() {
  local bin=''
  for candidate in codex-desktop codex Codex openai-codex; do
    if command -v "$candidate" >/dev/null 2>&1; then
      bin="$candidate"
      break
    fi
  done

  if [[ -z "$bin" ]]; then
    fail 'Codex Desktop executable was not found on PATH.'
  fi

  log "launching $bin with OpenAI/ChatGPT proxy bypass"
  build_env "$bin" "$@" >/dev/null 2>&1 &
  disown
}

main() {
  case "$(uname -s)" in
    Darwin) launch_macos "$@" ;;
    Linux) launch_linux "$@" ;;
    *) fail "unsupported platform: $(uname -s)" ;;
  esac

  log 'started Codex Desktop; try the session again after the window opens.'
}

main "$@"
