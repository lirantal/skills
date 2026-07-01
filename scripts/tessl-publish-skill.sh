#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <skill-directory-name>" >&2
  echo "Example: $0 codex-chat-organizer" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_dir="$repo_root/skills"
skill_name="${1%/}"
skill_name="${skill_name#skills/}"

if [[ -z "$skill_name" || "$skill_name" == *"/"* ]]; then
  usage
  exit 1
fi

skill_dir="$skills_dir/$skill_name"

if [[ ! -d "$skill_dir" ]]; then
  echo "Skill directory not found: $skill_dir" >&2
  exit 1
fi

if ! command -v tessl >/dev/null 2>&1; then
  echo "tessl CLI not found in PATH" >&2
  exit 1
fi

cd "$skills_dir"

echo "Importing $skill_name to Tessl workspace lirantal as public..."
tessl skill import "$skill_name/" --workspace lirantal --public

echo "Linting $skill_name..."
tessl skill lint "$skill_name"

echo "Publishing $skill_name..."
tessl skill publish "$skill_name"

echo "Done."
