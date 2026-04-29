#!/bin/bash
# Multi-repo bulk-edit template.
#
# Usage: copy this file, fill in the four CONFIG sections, and run.
# Reads candidates from $CANDIDATES (TSV: repo<TAB>...meta), opens one PR per repo.
# Logs to $OK / $SKIP / $FAIL — continues on any failure.

# Set PATH explicitly: subshells invoked from non-interactive contexts may not
# inherit /opt/homebrew/bin and miss jq, gh, column, etc.
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/local/bin:$PATH"
set -u

# === CONFIG 1: branch + PR metadata ==========================================
BRANCH='fix/short-slug-describing-the-change'
COMMIT_MSG='fix: short imperative summary of the change'
PR_TITLE="$COMMIT_MSG"
PR_BODY='One paragraph explaining what changed and why. Keep it short — reviewers need context, not a novel.'

# === CONFIG 2: I/O paths =====================================================
WORKDIR=/tmp/multi-repo-edit-<slug>
mkdir -p "$WORKDIR"
CANDIDATES=$WORKDIR/candidates.tsv   # produced by your scan phase
OK=$WORKDIR/ok.log
SKIP=$WORKDIR/skip.log
FAIL=$WORKDIR/fail.log
: > "$OK"; : > "$SKIP"; : > "$FAIL"

# === CONFIG 3: detection + transformation ====================================
# Implement transform_file() to read the input file, mutate it, and emit the
# new content. Return 0 on success, nonzero to skip (with a reason printed to
# stderr). The function receives:
#   $1 = repo (owner/name)
#   $2 = path to the current file content (read this)
#   $3 = path to write the new content to
transform_file() {
  local repo="$1" infile="$2" outfile="$3"

  # Example: remove all lines containing a specific URL pattern
  if ! grep -qE 'EXAMPLE_PATTERN' "$infile"; then
    echo "no_match" >&2
    return 1
  fi
  sed -E '/EXAMPLE_PATTERN/d' "$infile" > "$outfile"

  # Sanity-check: if your transform should always change something, verify it
  if cmp -s "$infile" "$outfile"; then
    echo "no_change_after_transform" >&2
    return 1
  fi
  return 0
}

# === CONFIG 4: which file to edit per repo ===================================
# Default: the README. Override if you're editing a different file.
# Set FILE_PATH empty to use the /readme endpoint (case-insensitive lookup).
FILE_PATH=''   # e.g. '.github/workflows/ci.yml' to edit a workflow

# =============================================================================
# You shouldn't need to edit below this line for typical bulk edits.
# =============================================================================

process_repo() {
  local repo="$1"
  local tmpdir; tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  # 1. Fetch the file
  local resp path sha
  if [ -z "$FILE_PATH" ]; then
    resp=$(gh api "repos/$repo/readme" 2>/dev/null) \
      || { echo "$repo	fetch_failed" >> "$FAIL"; return 1; }
  else
    resp=$(gh api "repos/$repo/contents/$FILE_PATH" 2>/dev/null) \
      || { echo "$repo	fetch_failed" >> "$FAIL"; return 1; }
  fi
  path=$(jq -r .path <<<"$resp")
  sha=$(jq -r .sha <<<"$resp")
  jq -r .content <<<"$resp" | base64 -d > "$tmpdir/before" \
    || { echo "$repo	decode_failed" >> "$FAIL"; return 1; }

  # 2. Transform
  local skip_reason
  skip_reason=$(transform_file "$repo" "$tmpdir/before" "$tmpdir/after" 2>&1 >/dev/null)
  if [ $? -ne 0 ]; then
    echo "$repo	${skip_reason:-skipped}" >> "$SKIP"
    return 0
  fi

  # 3. Default branch + HEAD SHA
  local default_branch head_sha
  default_branch=$(gh api "repos/$repo" -q .default_branch 2>/dev/null) \
    || { echo "$repo	default_branch_failed" >> "$FAIL"; return 1; }
  head_sha=$(gh api "repos/$repo/git/ref/heads/$default_branch" -q .object.sha 2>/dev/null) \
    || { echo "$repo	head_sha_failed" >> "$FAIL"; return 1; }

  # 4. Create branch (idempotent skip if it already exists)
  if gh api "repos/$repo/git/ref/heads/$BRANCH" >/dev/null 2>&1; then
    echo "$repo	branch_already_exists" >> "$SKIP"
    return 0
  fi
  gh api -X POST "repos/$repo/git/refs" \
    -f ref="refs/heads/$BRANCH" -f sha="$head_sha" >/dev/null 2>&1 \
    || { echo "$repo	branch_create_failed" >> "$FAIL"; return 1; }

  # 5. Commit
  local new_content
  new_content=$(base64 < "$tmpdir/after" | tr -d '\n')
  gh api -X PUT "repos/$repo/contents/$path" \
    -f message="$COMMIT_MSG" \
    -f content="$new_content" \
    -f sha="$sha" \
    -f branch="$BRANCH" >/dev/null 2>"$tmpdir/commit.err" \
    || { echo "$repo	commit_failed: $(tr '\n' ' ' < "$tmpdir/commit.err")" >> "$FAIL"; return 1; }

  # 6. PR
  local pr_url
  pr_url=$(gh pr create -R "$repo" \
    --base "$default_branch" --head "$BRANCH" \
    --title "$PR_TITLE" --body "$PR_BODY" 2>"$tmpdir/pr.err") \
    || { echo "$repo	pr_create_failed: $(tr '\n' ' ' < "$tmpdir/pr.err")" >> "$FAIL"; return 1; }

  echo "$repo	$pr_url" >> "$OK"
  echo "OK $repo -> $pr_url"
}

if [ ! -s "$CANDIDATES" ]; then
  echo "no candidates file at $CANDIDATES — run your scan phase first" >&2
  exit 1
fi

while IFS=$'\t' read -r repo _meta; do
  echo "--- $repo"
  process_repo "$repo"
done < "$CANDIDATES"

echo
echo "==== DONE ===="
echo "OK:   $(wc -l < "$OK" | tr -d ' ')"
echo "SKIP: $(wc -l < "$SKIP" | tr -d ' ')"
echo "FAIL: $(wc -l < "$FAIL" | tr -d ' ')"
[ -s "$SKIP" ] && { echo; echo "--- skipped ---"; cat "$SKIP"; }
[ -s "$FAIL" ] && { echo; echo "--- failed ---";  cat "$FAIL"; }
echo
echo "View the resulting PRs: gh search prs --author=@me --state=open --head=$BRANCH"
