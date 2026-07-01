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

manifest_path_for() {
  local skill_name="$1"

  printf '%s\n' "$skills_dir/$skill_name/.tessl-plugin/plugin.json"
}

manifest_version() {
  local manifest_path="$1"

  awk -F'"' '/"version"[[:space:]]*:/ { print $4; exit }' "$manifest_path"
}

next_patch_version() {
  local version="$1"

  if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$((BASH_REMATCH[3] + 1))"
    return 0
  fi

  return 1
}

bump_manifest_patch_version() {
  local manifest_path="$1"
  local current_version
  local next_version

  current_version="$(manifest_version "$manifest_path")"

  if [[ -z "$current_version" ]]; then
    echo "Could not find version in $manifest_path" >&2
    return 1
  fi

  if ! next_version="$(next_patch_version "$current_version")"; then
    echo "Could not patch-bump non-semver version '$current_version' in $manifest_path" >&2
    return 1
  fi

  perl -0pi -e 's/"version"\s*:\s*"[^"]+"/"version": "'"$next_version"'"/' "$manifest_path"
  printf '%s\n' "$next_version"
}

publish_skill() {
  local skill_name="$1"
  local max_bumps="${TESSL_PUBLISH_MAX_BUMPS:-20}"
  local bump_count=0
  local manifest_path
  local next_version
  local publish_output
  local publish_status

  manifest_path="$(manifest_path_for "$skill_name")"

  if [[ ! -f "$manifest_path" ]]; then
    echo "Tessl manifest not found: $manifest_path" >&2
    return 1
  fi

  while true; do
    echo "Publishing $skill_name..."

    set +e
    publish_output="$(tessl skill publish "$skill_name" 2>&1)"
    publish_status=$?
    set -e

    printf '%s\n' "$publish_output"

    if [[ $publish_status -eq 0 ]]; then
      return 0
    fi

    if [[ "$publish_output" != *"already exists"* ]]; then
      return "$publish_status"
    fi

    if [[ "$bump_count" -ge "$max_bumps" ]]; then
      echo "Version already exists for $skill_name after $max_bumps patch bump attempts; stopping." >&2
      return "$publish_status"
    fi

    next_version="$(bump_manifest_patch_version "$manifest_path")"
    bump_count=$((bump_count + 1))
    echo "Version already exists for $skill_name; retrying with manifest version $next_version..."
  done
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
