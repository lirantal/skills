---
name: gh-multi-repo-edits
description: Perform identical, surgical edits across many GitHub repositories without cloning them locally — using the `gh` CLI's Contents API to read files, create branches, commit changes, and open PRs in bulk. Use this skill whenever the user wants to make the same small change (update a README, remove a deprecated badge, fix a link, bump a config) across more than a handful of repos they own or maintain. Trigger this skill on phrases like "across all my repos", "in each of these repos", "bulk update", "open PRs for all of them", "without cloning", "deprecated X in many repos", or any task where the work is mechanically identical and spans 5+ repositories. Even when the user describes the task in domain terms (e.g. "the Snyk badge is deprecated everywhere") rather than "multi-repo edit", trigger this skill — it's the right tool whenever cloning N repos to make a one-line change would be wasteful.
---

# Multi-repo edits via the GitHub Contents API

## Why this skill exists

Cloning tens or hundreds of repos to make a one-line README change is wasteful and slow. The GitHub Contents API lets you read a file, modify it, and commit the change on a new branch, then open a PR — all without ever cloning. The `gh` CLI is already authenticated, so the whole flow can be a single bash script.

The pattern this skill encodes is **scan → verify on a sample → bulk apply with per-repo error handling**. Skipping any of those three steps tends to cause real damage in production: a sloppy regex matches prose instead of the badge you meant to remove; a workflow name doesn't map to its filename; one repo's default branch is `master` not `main`; you discover this halfway through because you didn't dry-run.

## When to use this skill

Use it when **all** of these are true:
- The change is mechanical (the same edit, parametrized at most by repo metadata like default branch or owner)
- It spans more than a handful of repositories
- The user has push access (or the repos are theirs)
- The change is safe to attempt unattended on each repo (you're opening PRs, not merging them)

If any of those are false — e.g. one repo, a hand-tailored change, a destructive force-push — write a one-off script instead. This skill is for fan-out, not for surgery on a single repo.

## The three-phase workflow

### Phase 1: Scan (no writes)

Build a list of candidate repos and detect, per repo, exactly what the change should be. Write nothing. The output is a candidates file plus a log of skip reasons.

```bash
# List the user's source repos (skip forks and archives)
gh repo list <user-or-org> --limit 300 --no-archived --source --json nameWithOwner -q '.[].nameWithOwner'
```

For each repo, fetch the file you intend to change. The `/readme` endpoint is preferred for READMEs because it finds the file regardless of casing (`README.md`, `Readme.md`, etc.):

```bash
gh api "repos/$repo/readme"               # returns {path, sha, content (base64)}
gh api "repos/$repo/contents/$path"        # for any other file
```

Run your detection logic on the decoded content. Write three log files:
- **candidates** (TSV): repos that need the change, plus any per-repo metadata you'll need in the apply phase
- **skips** (TSV): repos you intentionally won't touch, with reasons (`no_match`, `already_done`, `unsupported_variant`, etc.)
- **failures** (TSV): repos where detection itself errored (network, 404, parse fail)

When a single repo can have **multiple in-scope items** (e.g. several entries in a YAML array, several badge instances in a README, several workflow files), also write a fourth log:
- **details** (TSV): one row per item with its classification (e.g. `already_ok`, `needs_replace`, `needs_insert`)

The details file lets you see the **bucket distribution** before writing the transform — which is the cheapest way to keep the transform simple. If only one bucket is non-empty (e.g. every item to fix is the same kind), don't write a generalized transform that handles all theoretical cases. Pick the minimum transform that covers the populated buckets.

Show the candidate count, the bucket distribution, and a sample of skip reasons to the user before proceeding. Suspiciously high skip counts often mean the detection regex is too narrow.

### Phase 2: Verify on a sample

Pick **1–2 random candidates** and produce a full before/after for them. Show the user:
- The exact line(s) being matched
- The proposed replacement
- Any per-repo metadata you derived from the API (default branch, mapped filenames, etc.)

Wait for explicit user approval. This is the cheapest gate that catches the most expensive class of mistakes — a regex that looked right on the example you wrote it for but matches prose elsewhere, an edit that strips the wrong line, a metadata lookup that returns the wrong key.

For samples on a list of repos: `awk -F'\t' '{print $1}' candidates.tsv | sort -R | head -2` (`shuf` may be unavailable on macOS).

### Phase 3: Apply (bulk)

Per repo, in this exact order:

1. **Refetch the file** to get a fresh `sha` (don't trust the scan-time SHA — repos may have changed)
2. **Apply the transformation** in-memory
3. **Sanity-check** the result (e.g., grep that the new content is present and the old isn't)
4. **Look up the default branch**: `gh api repos/$repo -q .default_branch`
5. **Get the HEAD SHA** of the default branch: `gh api repos/$repo/git/ref/heads/$default_branch -q .object.sha`
6. **Create the working branch** off that HEAD:
   ```bash
   gh api -X POST repos/$repo/git/refs -f ref="refs/heads/$BRANCH" -f sha="$head_sha"
   ```
   If this fails with 422, the branch already exists from a previous run — skip and log, don't try to overwrite.
7. **Commit the change** via the Contents API:
   ```bash
   gh api -X PUT "repos/$repo/contents/$path" \
     -f message="$COMMIT_MSG" \
     -f content="$(base64 < new_file | tr -d '\n')" \
     -f sha="$FILE_SHA" \
     -f branch="$BRANCH"
   ```
8. **Open the PR**:
   ```bash
   gh pr create -R "$repo" --base "$default_branch" --head "$BRANCH" \
     --title "$PR_TITLE" --body "$PR_BODY"
   ```

Wrap each repo's work in a function that returns nonzero on any failure, and run it in a loop that **continues on failure** — log to a failures file, move on. One bad repo shouldn't block the other 43.

### Reporting

End with a summary the user can act on:
- Successes: count + path to the log of PR URLs
- Skips: count + grouped by reason
- Failures: count + the actual error per repo
- The exact `gh search` command to view all the PRs together:
  ```bash
  gh search prs --author=@me --state=open --head="$BRANCH"
  ```

## Recommended script structure

A single bash script with these properties holds up well:

```bash
#!/bin/bash
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/local/bin:$PATH"  # see Pitfalls below
set -u

BRANCH='fix/some-thing'
COMMIT_MSG='fix: short imperative summary'
PR_TITLE="$COMMIT_MSG"
PR_BODY='One paragraph explaining what changed and why.'

OK=/tmp/<scope>/ok.log; SKIP=/tmp/<scope>/skip.log; FAIL=/tmp/<scope>/fail.log
: > "$OK"; : > "$SKIP"; : > "$FAIL"

process_repo() {
  local repo="$1"
  local tmpdir; tmpdir=$(mktemp -d)
  trap "rm -rf '$tmpdir'" RETURN

  # --- fetch ---
  # --- detect / transform ---
  # --- sanity-check ---
  # --- branch + commit + PR ---
  # log to OK / SKIP / FAIL with tab-separated rows: repo<TAB>reason_or_url
}

while IFS=$'\t' read -r repo _meta; do
  echo "--- $repo"
  process_repo "$repo"   # do NOT `|| return` here — we want to continue
done < candidates.tsv

echo "OK: $(wc -l < "$OK"), SKIP: $(wc -l < "$SKIP"), FAIL: $(wc -l < "$FAIL")"
```

Two structural choices that matter:
- **One function per repo** with `local` everything and a cleanup trap. Loops over hundreds of repos otherwise leak `$tmpdir`s.
- **Continue on error**. The bulk run's value is fan-out; aborting on one failure defeats the point.

## Pitfalls (this stuff bit us — do not relearn)

- **Probe for tools before reaching for an install.** Don't reflexively `pip install` / `npm install` / `brew install` a parser library mid-task — many users keep their environment lean and won't appreciate the install. Before you write the script, run a quick probe to see what's actually available, e.g.:
  ```bash
  which yq jq node python3 ruby perl
  python3 -c 'import yaml' 2>&1 | head -1   # PyYAML
  ruby -ryaml -e 'p YAML.load("a: 1")' 2>&1 # Ruby's YAML is stdlib — usually present
  ```
  Pick whichever installed tool can do the job (Ruby's `Psych` and Perl's `YAML` are stdlib on macOS; `jq` is universally available; `node` may have nothing extra without npm). If absolutely nothing on the system can parse the format you need, surface the constraint to the user and ask before installing.

- **PATH in subshells.** When a script is invoked from a non-interactive context, the inherited `PATH` may not include `/opt/homebrew/bin` (Homebrew tools like `jq`, `gh`, `column`). Set `PATH` explicitly at the top of every script.

- **`for x in $VAR` doesn't always split on newlines.** The IFS in some shells doesn't include `\n`, so a multi-line `$SAMPLE` becomes a single iteration with a string like `"repo1\nrepo2"` that gets sent to `gh api` and produces `invalid control character in URL`. Use `... | while read -r repo` instead.

- **`printf '%b'` can introduce NUL bytes.** Bash's `printf '%b'` is a footgun for URL-decoding — it can leave trailing nulls. URL-decode in Python instead:
  ```bash
  python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.argv[1]).rstrip())" "$encoded"
  ```

- **Don't interpolate variables into `jq` filters.** A workflow name with a space or quote breaks the filter. Use `--arg`:
  ```bash
  gh api ... | jq -r --arg n "$wf_name" '.workflows[] | select(.name == $n) | .path'
  ```

- **Beware regexes that match prose.** A pattern like `Known Vulnerabilities` matched section headings and TOC entries, not just the badge alt text. Prefer **structural signals** (URLs, tag attributes, file paths) over **labels**. When in doubt, require a URL substring.

- **Workflow name ≠ workflow filename.** GitHub's old badge URL `/workflows/<name>/badge.svg` uses the workflow's `name:` field. The new URL needs the workflow's *file path* (`ci.yml`, `main.yml`, etc.). Resolve via `GET /repos/{owner}/{repo}/actions/workflows`, which returns `[{name, path}, …]`. Map by `name`, then `basename` the `path`.

- **Default branch is not always `main`.** Don't hardcode. `gh api repos/$repo -q .default_branch` per repo — `master`, `develop`, etc. all show up in the wild.

- **README casing varies.** Use the `/readme` endpoint, not `/contents/README.md`, when fetching READMEs.

- **Heredoc + bash variable substitution is fragile.** When passing complex strings (matched lines, multi-character substitutions) to a python heredoc, prefer `python3 - "$arg1" "$arg2" <<'PYEOF'` (note the quoted `'PYEOF'`) and read via `sys.argv`. Unquoted heredocs get bash-substituted and lose newlines/spaces unpredictably.

- **Idempotency.** Always check whether the working branch already exists before creating it (a previous run may have left it). Treat 422 as "skip + log", not "fail".

- **Trailing conditional → bogus exit code.** A script ending with `[[ -s "$FAIL" ]] && cat "$FAIL"` exits 1 when `$FAIL` is empty, because the conditional is the script's last command and evaluates false. Everything succeeded, but the wrapping shell sees failure. Either guard each conditional with `|| true`, follow the conditional with an unconditional command (an `echo`, a hint to view PRs), or end the script with an explicit `exit 0`.

## Detection: a worked example

This is the pattern from a real run. The user wanted to remove the deprecated Snyk vulnerabilities badge from many READMEs.

**First-cut regex (too loose):**
```
grep -E 'Known Vulnerabilities|snyk\.io/test/'
```
The alt-text alternative caught two false positives (a section heading "Scan for Known Vulnerabilities" and its TOC entry). Lesson: prefer the URL signal alone:
```
grep -E 'snyk\.io/test/'
```

**Form-agnostic substitution.** The badge appears in two forms:
- HTML: `<a href="..."><img src=".../workflows/CI/badge.svg" alt="build"/></a>`
- Markdown: `[![build](.../workflows/CI/badge.svg)](.../actions?workflow=CI)`

Rather than parse the line, do **substring replacements on the URLs themselves** — both forms share the same URL structure, so URL-level edits are form-agnostic:
```python
new = old.replace(
    f'/workflows/{name}/badge.svg',
    f'/actions/workflows/{file}/badge.svg?branch={branch}'
).replace(
    f'/actions?workflow={name}',
    f'/actions/workflows/{file}'
)
```

This generalizes: when transforming a URL that may appear in multiple wrapper formats, edit the URL substring and let the wrappers stay as they are.

## Structured config edits (YAML / JSON / TOML): a second worked example

The URL-substitution pattern above breaks down when the file is structured config (`.github/dependabot.yml`, `package.json`, `pyproject.toml`, etc.), because:
- Indent and nesting *matter* — sed/grep can't reason about them.
- Round-tripping through a parser typically **loses comments and ordering** (the user's original `# Why this thing exists` lines disappear).
- The change isn't always at one literal location — e.g. "ensure each entry under `updates:` has a `labels:` key" requires walking N entries and inserting in the right place under each.

The workable pattern is a **parse–edit–verify** split:

1. **Parse to decide** — use a YAML/JSON parser (Ruby's `YAML` is stdlib, Perl's `YAML` is stdlib, `jq` for JSON) to classify each in-scope item: already correct, needs modification, missing entirely. This is purely diagnostic — no writes.

2. **Surgical line edits to transform** — once you know which items need what, edit the source text line-by-line: locate the entry by its anchor line (e.g. `- package-ecosystem:`), determine sibling indent from that line's column, and insert / modify lines at the right indent. Don't round-trip through a YAML dumper unless you genuinely don't care about comments or key order.

3. **Re-parse to verify the structural invariant** — after editing, parse the new content again and assert what you wanted is now true (e.g. `every entry now has labels containing both X and Y`). Failing this assertion should abort the per-repo run before any branch/commit/PR.

4. **Plus a literal grep sanity check** — count occurrences in the new content (e.g. `# of "labels:" lines >= # of "- package-ecosystem:" lines`). The parser check confirms structure, the grep check confirms exact text presence — they catch different failure modes (a parser-valid file with the wrong indent, vs. a missing line).

A real example from a dependabot.yml run: parser-side, classify each `updates[*]` entry as `ok` / `needs_block` / `needs_add`. Line-side, for each `- package-ecosystem:` line, find sibling indent (`dash_col + 2`), find the end of that entry's range (next `- package-ecosystem:` at the same column, or EOF, ignoring trailing blank lines), and insert the labels block just before any trailing blank-line separator. Re-parse the result and assert each entry's `labels` array now contains the targets; also grep that `labels:` count ≥ ecosystem count. **Iterate from the bottom up** when inserting into a line array, so earlier line indices remain valid.

A few file-format gotchas worth noting:
- **Extension variants** — try `.yml` then `.yaml`; `.toml` vs `.cfg`; on 404 of one, fall through to the other before declaring "no match."
- **Bucket distribution drives transform complexity** — if your scan shows every needs-change item is the same kind, don't write code for the other theoretical kinds. Less code, less bug surface, faster sample diff.

## When to confirm with the user

This skill drives **side-effecting, externally-visible** changes (PRs that notify reviewers, hit inboxes, may auto-trigger CI). Confirm before:

- The first dry-run finishes and you're about to apply (always)
- Bulk runs that exceed the dry-run sample size (always)
- Any unusual skip count (more skips than candidates, or skips with reasons you didn't predict — investigate first)
- Pacing: 50+ PRs at once produces a notification burst; offer the user the option to chunk

The user has *tools* but they don't have *time*. Confirm with a one-line summary plus a 2-option pick (proceed all / chunk into N) — not with paragraphs.

## What this skill does NOT do

- It does **not** merge PRs. Opening PRs is reversible (close them); merging changes mainline.
- It does **not** use destructive git operations (force-push, branch delete on remote, etc.) — the Contents API path is non-destructive by design.
- It does **not** handle binary files well — the Contents API is base64 round-trip safe, but if the change is to a binary, you probably want a different approach.
- It does **not** scale to thousands of repos in one run. GitHub's authenticated rate limit is 5000/hour, and each repo costs ~5 calls (readme, default branch, head sha, ref create, contents PUT, pr create). 200–300 repos per run is comfortable; beyond that, batch.

## Reference files

- `references/api-recipes.md` — Common `gh api` patterns: read file, write file with branch, list workflows, list PRs, etc.
- `references/script-template.sh` — A starting-point bash script with the structure described above; copy and customize per task.
