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

## Webhooks (list / health-check / delete)

Webhooks aren't a first-class `gh` command, but the full REST API is reachable via `gh api`. Needs `admin:repo_hook` scope (repo) or `admin:org_hook` (org). The `config.secret` is write-only — it never comes back in GETs.

```bash
# List a repo's webhooks with the status of their most recent delivery
gh api "repos/<owner>/<repo>/hooks" \
  -q '.[] | "\(.id)\t\(.config.url)\t\(.last_response.code)\t\(.last_response.status)"'

# Fields that matter per hook: .id, .active, .events, .config.url, .last_response{code,status,message}
```

**`last_response` is a snapshot of the single most-recent delivery, and its `status` lies by omission.** A hook that has never fired shows `code:0, status:"unused"` — that is NOT the same as dead. `unused` ≠ broken; it just means GitHub has had no event to deliver. To learn the endpoint's *actual* health, manufacture a delivery with a **ping** (cheap, non-destructive, no commit/CI/notification noise — unlike an empty commit, which fires a `push` plus everything else):

```bash
# 1. Ping the hook — GitHub sends a `ping` event to the endpoint on demand
gh api -X POST "repos/<owner>/<repo>/hooks/<hook_id>/pings"

# 2. Read the result (deliveries register within a few seconds)
gh api "repos/<owner>/<repo>/hooks/<hook_id>/deliveries" \
  -q 'map(select(.event=="ping")) | .[0] | "\(.status_code)\t\(.status)"'
# 2xx = endpoint alive & accepting; 403/410/502/etc = dead or rejected.

# Full delivery history (req/resp bodies for one delivery)
gh api "repos/<owner>/<repo>/hooks/<hook_id>/deliveries"
gh api "repos/<owner>/<repo>/hooks/<hook_id>/deliveries/<delivery_id>"

# Re-send a past delivery
gh api -X POST "repos/<owner>/<repo>/hooks/<hook_id>/deliveries/<delivery_id>/attempts"

# Delete a hook (destructive — confirm scope with the user first)
gh api -X DELETE "repos/<owner>/<repo>/hooks/<hook_id>"
```

**Bulk webhook cleanup maps onto the three-phase workflow:** scan = list hooks across all repos and bucket by `last_response.code` (`healthy` 2xx / `unhealthy` 3xx-5xx / `undelivered` 0 i.e. `unused`); verify = **ping the `undelivered` bucket** and re-read `status_code` to split genuinely-dead from healthy-but-idle; apply = delete only the hooks whose ping (or last delivery) is non-2xx. Keep the `gh api -X DELETE` exit code as your success signal. Note `last_response` only covers repo hooks reached via `repos/.../hooks`; org-level hooks live at `orgs/<org>/hooks`.

> A real run: 104 hooks across 522 repos bucketed to 3 healthy / 10 unhealthy / 91 `unused`. Pinging the `unused` bucket proved 18 codecov hooks were genuinely rejected (403) while 38 Snyk/Codefresh hooks were healthy-but-idle (200). Deleting the whole `unused` bucket blindly would have destroyed 38 working integrations — the ping is what made the distinction. `notify.travis-ci.org` hooks were dead regardless of recorded state (service decommissioned), so they were deleted by URL match, not by ping.

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
