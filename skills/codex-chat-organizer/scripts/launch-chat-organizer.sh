#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_PATH=""
DRY_RUN=0
NO_REOPEN=0

usage() {
  printf 'Usage: %s <plan.json> [--dry-run] [--no-reopen]\n' "$(basename "$0")"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --no-reopen)
      NO_REOPEN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [ -z "$PLAN_PATH" ]; then
        PLAN_PATH="$1"
        shift
      else
        printf 'Unknown argument: %s\n' "$1" >&2
        usage >&2
        exit 2
      fi
      ;;
  esac
done

if [ -z "$PLAN_PATH" ] || [ ! -f "$PLAN_PATH" ]; then
  printf 'Plan file not found: %s\n' "${PLAN_PATH:-<missing>}" >&2
  exit 2
fi

HELPER_ARGS=(--plan "$PLAN_PATH")
if [ "$DRY_RUN" -eq 1 ]; then
  HELPER_ARGS+=(--dry-run)
fi
if [ "$NO_REOPEN" -eq 1 ]; then
  HELPER_ARGS+=(--no-reopen)
fi

COMMAND="$(printf '%q ' "$SCRIPT_DIR/run-move-helper.sh" "${HELPER_ARGS[@]}")"
TERMINAL_CHOICE="${CODEX_CHAT_ORGANIZER_TERMINAL:-}"
if [ -z "$TERMINAL_CHOICE" ] && [ -f "$HOME/.codex/chat-organizer-terminal" ]; then
  TERMINAL_CHOICE="$(tr -d '[:space:]' < "$HOME/.codex/chat-organizer-terminal")"
fi

app_exists() {
  open -Ra "$1" >/dev/null 2>&1
}

launch_terminal() {
  osascript -e "tell application \"Terminal\" to activate" \
    -e "tell application \"Terminal\" to do script \"$COMMAND\""
}

launch_iterm() {
  osascript <<APPLESCRIPT
tell application "iTerm"
  activate
  create window with default profile command "$COMMAND"
end tell
APPLESCRIPT
}

launch_wezterm() {
  if command -v wezterm >/dev/null 2>&1; then
    wezterm start -- zsh -lc "$COMMAND" >/dev/null 2>&1 &
  else
    open -na "WezTerm" --args start -- zsh -lc "$COMMAND"
  fi
}

launch_ghostty() {
  open -na "Ghostty" --args -e zsh -lc "$COMMAND"
}

TERMINAL_CHOICE_LOWER="$(printf '%s' "$TERMINAL_CHOICE" | tr '[:upper:]' '[:lower:]')"

case "$TERMINAL_CHOICE_LOWER" in
  terminal|apple-terminal|apple_terminal)
    launch_terminal
    ;;
  iterm|iterm2)
    launch_iterm
    ;;
  wezterm)
    launch_wezterm
    ;;
  ghostty)
    launch_ghostty
    ;;
  "")
    if app_exists "iTerm"; then
      launch_iterm
    elif command -v wezterm >/dev/null 2>&1 || app_exists "WezTerm"; then
      launch_wezterm
    elif app_exists "Ghostty"; then
      launch_ghostty
    else
      launch_terminal
    fi
    ;;
  *)
    printf 'Unknown terminal preference "%s"; falling back to Apple Terminal.\n' "$TERMINAL_CHOICE" >&2
    launch_terminal
    ;;
esac

printf 'Launched Codex Chat Organizer helper in a terminal window.\n'
