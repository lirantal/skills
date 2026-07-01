#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <skill-directory-name|*> [skill-directory-name...]" >&2
  echo "Example: $0 codex-chat-organizer" >&2
  echo "Example: $0 '*'" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_dir="$repo_root/skills"

all_skill_names() {
  local skill_path
  local skill_names=()

  for skill_path in "$skills_dir"/*; do
    [[ -d "$skill_path" ]] || continue
    skill_names+=("$(basename "$skill_path")")
  done

  if [[ ${#skill_names[@]} -gt 0 ]]; then
    printf '%s\n' "${skill_names[@]}"
  fi
}

normalize_skill_name() {
  local skill_name="$1"

  skill_name="${skill_name%/}"
  skill_name="${skill_name#"$skills_dir"/}"
  skill_name="${skill_name#skills/}"

  printf '%s\n' "$skill_name"
}

is_repo_root_glob_expansion() {
  [[ $# -gt 1 ]] || return 1

  local arg
  local normalized
  local has_skills_dir=false
  local has_non_skill_arg=false

  for arg in "$@"; do
    normalized="$(normalize_skill_name "$arg")"

    if [[ "$normalized" == "skills" ]]; then
      has_skills_dir=true
      has_non_skill_arg=true
      continue
    fi

    if [[ ! -d "$skills_dir/$normalized" ]]; then
      has_non_skill_arg=true
    fi
  done

  [[ "$has_skills_dir" == true && "$has_non_skill_arg" == true ]]
}

publish_skill() {
  local skill_name="$1"
  local publish_output
  local publish_status

  echo "Publishing $skill_name..."

  set +e
  publish_output="$(tessl skill publish "$skill_name" 2>&1)"
  publish_status=$?
  set -e

  printf '%s\n' "$publish_output"

  if [[ $publish_status -eq 0 ]]; then
    return 0
  fi

  if [[ "$publish_output" == *"already exists"* ]]; then
    echo "Version already exists for $skill_name; retrying with --bump patch..."
    tessl skill publish "$skill_name" --bump patch
    return 0
  fi

  return "$publish_status"
}

target_skill_names=()

if [[ "$*" == "*" || "$*" == "skills/*" ]] || is_repo_root_glob_expansion "$@"; then
  while IFS= read -r skill_name; do
    target_skill_names+=("$skill_name")
  done < <(all_skill_names)
else
  for arg in "$@"; do
    skill_name="$(normalize_skill_name "$arg")"

    if [[ -z "$skill_name" || "$skill_name" == *"/"* ]]; then
      usage
      exit 1
    fi

    skill_dir="$skills_dir/$skill_name"

    if [[ ! -d "$skill_dir" ]]; then
      echo "Skill directory not found: $skill_dir" >&2
      exit 1
    fi

    target_skill_names+=("$skill_name")
  done
fi

if [[ ${#target_skill_names[@]} -eq 0 ]]; then
  echo "No skill directories found under $skills_dir" >&2
  exit 1
fi

if ! command -v tessl >/dev/null 2>&1; then
  echo "tessl CLI not found in PATH" >&2
  exit 1
fi

cd "$skills_dir"

for skill_name in "${target_skill_names[@]}"; do
  echo "Importing $skill_name to Tessl workspace lirantal as public..."
  tessl skill import "$skill_name/" --workspace lirantal --public

  echo "Linting $skill_name..."
  tessl skill lint "$skill_name"

  publish_skill "$skill_name"
done

echo "Done."
