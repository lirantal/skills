# gh CLI / GitHub API recipes for bulk repo edits

All examples assume `gh` is authenticated. Substitute `<owner>`, `<repo>`, `<path>`, `<branch>` as appropriate.

## Listing repos

```bash
# All your non-archived source repos (excludes forks)
gh repo list <owner> --limit 300 --no-archived --source --json nameWithOwner -q '.[].nameWithOwner'

# Add default branch info if you need it
gh repo list <owner> --limit 300 --json nameWithOwner,defaultBranchRef \
  -q '.[] | "\(.nameWithOwner)\t\(.defaultBranchRef.name)"'

# Org repos (same flags work)
gh repo list <org> --limit 1000 --no-archived --source --json nameWithOwner -q '.[].nameWithOwner'
```

## Reading a file

```bash
# README (case-insensitive, finds README.md / Readme.md / README.rst, etc.)
gh api "repos/<owner>/<repo>/readme"
# returns { name, path, sha, content (base64), encoding, ... }

# Any file at a known path
gh api "repos/<owner>/<repo>/contents/<path>"

# Just the decoded content
gh api "repos/<owner>/<repo>/contents/<path>" -q .content | base64 -d

# Just the SHA (needed for updates)
gh api "repos/<owner>/<repo>/contents/<path>" -q .sha
```

## Writing a file (branch + commit + PR)

```bash
# 1. Get default branch + HEAD SHA
DEFAULT_BRANCH=$(gh api "repos/<owner>/<repo>" -q .default_branch)
HEAD_SHA=$(gh api "repos/<owner>/<repo>/git/ref/heads/$DEFAULT_BRANCH" -q .object.sha)

# 2. Create a working branch
gh api -X POST "repos/<owner>/<repo>/git/refs" \
  -f ref="refs/heads/<branch>" \
  -f sha="$HEAD_SHA"
# Returns 422 if branch already exists — handle gracefully.

# 3. Refetch file SHA right before commit (don't trust scan-time SHA)
FILE_SHA=$(gh api "repos/<owner>/<repo>/contents/<path>" -q .sha)

# 4. Commit (PUT replaces the whole file with new base64 content)
NEW_CONTENT=$(base64 < new_file | tr -d '\n')   # macOS: base64 -i
gh api -X PUT "repos/<owner>/<repo>/contents/<path>" \
  -f message="<commit message>" \
  -f content="$NEW_CONTENT" \
  -f sha="$FILE_SHA" \
  -f branch="<branch>"

# 5. Open the PR
gh pr create -R "<owner>/<repo>" \
  --base "$DEFAULT_BRANCH" \
  --head "<branch>" \
  --title "<title>" \
  --body "<body>"
```

## Repo metadata lookups

```bash
# Default branch
gh api "repos/<owner>/<repo>" -q .default_branch

# Topics, license, archived state, etc.
gh api "repos/<owner>/<repo>" -q '{topics, license: .license.spdx_id, archived, language}'

# Workflow file mapping (name -> path) — needed for badge URL transformations
gh api "repos/<owner>/<repo>/actions/workflows" \
  -q '.workflows[] | "\(.name)\t\(.path)\t\(.state)"'

# Map a specific workflow name to its file (use --arg, never interpolate)
gh api "repos/<owner>/<repo>/actions/workflows" \
  | jq -r --arg n "<workflow name>" '.workflows[] | select(.name == $n) | .path'
```

## Searching across PRs

```bash
# All your open PRs across every repo
gh search prs --author=@me --state=open

# Filter by branch (handy for finding all PRs from one bulk run)
gh search prs --author=@me --state=open --head=<branch>

# As clickable URLs
gh search prs --author=@me --state=open --head=<branch> \
  --json url,repository,title \
  -q '.[] | "\(.repository.nameWithOwner)\t\(.url)\t\(.title)"' \
  | column -t -s$'\t'

# Quick CI status check across all of them
gh search prs --author=@me --state=open --head=<branch> --json url -q '.[].url' \
  | while read -r url; do
      echo "=== $url ==="
      gh pr checks "$url" 2>/dev/null | head -5
    done
```

## Cleanup if a bulk run goes wrong

```bash
# Delete the working branch on a single repo (only safe before PR is merged)
gh api -X DELETE "repos/<owner>/<repo>/git/refs/heads/<branch>"

# Close all PRs from a bulk run (does not delete branches)
gh search prs --author=@me --state=open --head=<branch> --json url -q '.[].url' \
  | while read -r url; do gh pr close "$url"; done

# Close + delete branch in one go
gh search prs --author=@me --state=open --head=<branch> --json url -q '.[].url' \
  | while read -r url; do gh pr close "$url" --delete-branch; done
```

## Rate-limit awareness

Authenticated requests: 5000/hour. Each repo in a bulk run typically costs:
- 1 call: list repos (once for the whole run)
- 1 call: fetch README/file
- 1 call: get default branch
- 1 call: get HEAD SHA
- 1 call: create branch (or check existence)
- 1 call: commit (PUT contents)
- 1 call: create PR

≈ 6 calls per repo. 300 repos ≈ 1800 calls — well under the limit. Check remaining quota with:

```bash
gh api rate_limit -q .resources.core
```
