#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAN_PATH=""
DRY_RUN=0
NO_REOPEN=0
WAIT_BUFFER_SECONDS="${CODEX_CHAT_ORGANIZER_WAIT_BUFFER_SECONDS:-5}"
CODEX_PATTERN='Codex \(Renderer\)|Codex \(Service\)|/Applications/Codex.app/Contents/MacOS/Codex'

usage() {
  printf 'Usage: %s --plan <plan.json> [--dry-run] [--no-reopen]\n' "$(basename "$0")"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan)
      PLAN_PATH="${2:-}"
      shift 2
      ;;
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
      if [ -z "$PLAN_PATH" ] && [ -f "$1" ]; then
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

printf '\nCodex Chat Organizer\n'
printf 'Plan: %s\n\n' "$PLAN_PATH"

if [ "$DRY_RUN" -eq 1 ]; then
  node "$SCRIPT_DIR/apply-move-plan.mjs" --plan "$PLAN_PATH" --dry-run
  printf '\nDry run complete. No files changed.\n'
  exit 0
fi

node "$SCRIPT_DIR/apply-move-plan.mjs" --plan "$PLAN_PATH" --dry-run

printf '\nThis will quit Codex, wait for it to fully exit, patch local Codex state, and reopen Codex.\n'
printf 'Type MOVE and press Enter to continue: '
read -r CONFIRM
if [ "$CONFIRM" != "MOVE" ]; then
  printf 'Cancelled. No files changed.\n'
  exit 0
fi

printf '\nAsking Codex to quit...\n'
osascript -e 'tell application "Codex" to quit' >/dev/null 2>&1 || true

printf 'Waiting for Codex processes to exit'
while pgrep -f "$CODEX_PATTERN" >/dev/null 2>&1; do
  printf '.'
  sleep 2
done
printf '\nCodex has exited. Waiting %s seconds for final state flush...\n' "$WAIT_BUFFER_SECONDS"
sleep "$WAIT_BUFFER_SECONDS"

node "$SCRIPT_DIR/apply-move-plan.mjs" --plan "$PLAN_PATH"

REOPEN_FROM_PLAN="$(node -e 'const fs=require("fs"); const p=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(p.reopenCodex === false ? "0" : "1");' "$PLAN_PATH")"
if [ "$NO_REOPEN" -eq 0 ] && [ "$REOPEN_FROM_PLAN" = "1" ]; then
  printf '\nReopening Codex...\n'
  open -a Codex
else
  printf '\nLeaving Codex closed.\n'
fi

printf '\nDone. You can close this terminal window.\n'
