---
name: gh-bulk-pr-triage
description: Triage many open GitHub PRs at once — for each PR, check its CI verdict and mergeability, then merge (with admin bypass + squash fallback) or close, in bulk. Use when the user wants to clean up a queue of stale PRs ("close all the old Snyk PRs", "merge anything green and close anything red", "process all the dependabot PRs across my repos") spanning more than a handful of PRs. Trigger on phrases like "go through all my open PRs", "merge or close them all", "clean up the PR backlog", "any PR that's failing CI / unmergeable / stale", or when the user wants the same per-PR decision rule applied to a list of PRs. Sibling skill to `gh-bulk-repo-edit`, but the surface is PR state changes (merge / close / leave), not file contents.
---

# Bulk PR triage via the gh CLI

## Why this skill exists

A single user can accumulate dozens to hundreds of open PRs over time — Snyk, Dependabot, Renovate, contributors who never came back. Closing or merging them one-by-one is tedious and error-prone. The `gh` CLI exposes everything needed (`gh search prs`, `gh pr view --json statusCheckRollup`, `gh pr merge --admin`, `gh pr close`) to do it in a single bash loop with per-PR error handling.

This skill encodes a tested decision tree and a fallback chain for merge strategies — two things that aren't obvious until you've watched a bulk run fail interestingly.

## When to use this skill

Use it when **all** of these are true:
- The user wants the **same decision rule** applied to many PRs (≥10 typically)
- The decision is a function of CI verdict + mergeable state — not a function of the diff content
- The user has merge or admin permission on the target repos (otherwise `--admin` bypass won't work and many merges will fail)
- The user has explicitly authorized irreversible actions (merge, close)

If the user wants a per-PR judgment call, this is the wrong skill — they should review by hand. If the user wants to *edit* files in PRs to fix conflicts, that's also out of scope (different problem).

## The decision tree

For each PR, determine the **CI verdict** and **mergeability** independently — they are not the same thing — then act on the pair:

| CI verdict          | Mergeable? | Action                                |
|---------------------|------------|---------------------------------------|
| PASS or NONE        | yes        | merge (admin bypass)                  |
| PASS or NONE        | no         | **user-defined** — close, leave, or skip |
| FAIL                | any        | close                                 |
| PENDING             | any        | skip + log (don't act on incomplete state) |

The third row — "CI clean but unmergeable due to drift conflicts" — is the easy bucket to forget. On stale PRs (months or years old), it's often the *largest* bucket. Always ask the user explicitly what to do with it before bulk-running; the obvious answers ("close them, conflicts mean dead") and the also-obvious-but-different answers ("leave them, the original author may rebase") are both legitimate.

### CI verdict — derive it from `statusCheckRollup`

```bash
gh pr view "$pr" -R "$repo" --json statusCheckRollup
```

The rollup is a unified array of both **status contexts** (have `.state`) and **check runs** (have `.conclusion`). Coalesce to one field per item, then bucket:

```jq
[.statusCheckRollup[] | (.conclusion // .state // "") | ascii_downcase]
```

- **fail bucket**: `failure`, `cancelled`, `timed_out`, `action_required`, `error`
- **pending bucket**: `""` (unset), `pending`, `queued`, `in_progress`, `waiting`, `requested`
- **pass bucket**: everything else once non-empty (`success`, `neutral`, `skipped`)

Verdict logic: if `length == 0` → `NONE`; else if any in fail bucket → `FAIL`; else if any in pending bucket → `PENDING`; else → `PASS`.

`NONE` is real — many goof / demo / personal-script repos have no CI configured. Treat it as `PASS` by default but **always confirm with the user** before bulk-running, since "no CI" is sometimes a forgotten setup, not an intentional choice.

## The merge fallback chain

`gh pr merge --merge --admin` will fail on repos that disallow merge commits — error string contains `"Merge commits are not allowed"`. Fall back to `--squash --admin` in that case, then `--rebase --admin` if that also fails. Encode this as a function and run it in one pass — don't make the user wait through a first run that hits this and a second retry pass:

```bash
try_merge() {
  local repo="$1" pr="$2" out
  for strategy in --merge --squash --rebase; do
    out=$(gh pr merge "$pr" -R "$repo" $strategy --admin 2>&1)
    if [ $? -eq 0 ]; then echo "MERGED:$strategy"; return; fi
    echo "$out" | grep -q "are not allowed" || break  # not a strategy issue → stop trying
  done
  if echo "$out" | grep -qE "merge conflicts|cannot be cleanly created|not mergeable"; then
    echo "CONFLICT"; return
  fi
  echo "OTHER:$(echo "$out" | head -1)"
}
```

Three things make this work:
- **Iterate strategies** in `--merge → --squash → --rebase` order. Most repos accept at least one.
- **Break on non-strategy errors.** If the error isn't "X is not allowed," another strategy won't help — stop and propagate the original error.
- **Return a categorical code, not a boolean.** The caller needs to distinguish "merged with squash" from "blocked on conflict" from "unknown other failure" to bucket correctly.

## The three-phase workflow (mirrors `gh-bulk-repo-edit`)

### Phase 1: Discover

```bash
gh search prs --owner=<owner> --state=open --json number,title,repository \
  --limit 500 'in:title "<filter>"' \
  | jq -r '.[] | select(.title | startswith("<filter>")) | [.repository.nameWithOwner, .number, .title] | @tsv'
```

Two subtleties:
- **`gh search` filters loosely.** Searching `'in:title "[Snyk] Fix"'` returns PRs that contain that *substring* in the title — even `[Snyk] Security upgrade...` will match in some indexing modes. **Always re-filter client-side with `startswith`** (or a stricter regex) on the title.
- **`--owner=<user>` only finds repos that user owns.** Repos where the user is a collaborator/contributor on someone else's project won't show up. If the user wants those too, you need a separate strategy (e.g. `gh search prs --author=@me`).

Write a `candidates.tsv` (`repo<TAB>pr<TAB>title`) and report the count + per-repo distribution to the user before proceeding.

### Phase 2: Confirm scope

Always confirm before bulk-running because the actions are **destructive and externally visible** (merges hit prod, closes notify authors). The confirmation should include:
- Total PR count
- Per-repo distribution (top 10)
- Decision rule recap (especially how `NONE` and `unmergeable + CI clean` will be handled)
- Pacing note if >100 PRs (notification burst)

This is the same gate as `gh-bulk-repo-edit`'s sample-verify phase, except there's no diff to show — only counts and rules.

### Phase 3: Apply

Per-PR loop, log to four buckets:

```bash
while IFS=$'\t' read -r repo pr title; do
  v=$(verdict_for "$repo" "$pr")           # PASS|FAIL|PENDING|NONE|ERR
  case "$v" in
    FAIL)
      gh pr close "$pr" -R "$repo" >/dev/null && \
        echo "$repo	$pr	$title" >> closed_ci_fail.tsv ;;
    PASS|NONE)
      r=$(try_merge "$repo" "$pr")
      case "$r" in
        MERGED:*)  echo "$repo	$pr	$v	${r#MERGED:}	$title" >> merged.tsv ;;
        CONFLICT)
          gh pr close "$pr" -R "$repo" >/dev/null && \
            echo "$repo	$pr	$title" >> closed_conflict.tsv ;;
        OTHER:*)   echo "$repo	$pr	$r" >> errors.tsv ;;
      esac ;;
    PENDING)
      echo "$repo	$pr	$title" >> skipped_pending.tsv ;;
    *)
      echo "$repo	$pr	verdict=$v" >> errors.tsv ;;
  esac
done < candidates.tsv
```

**Continue on failure** — same rule as `gh-bulk-repo-edit`. One bad PR shouldn't block the rest.

### Reporting

Print a summary keyed on action taken, not on bucket:
- **Merged**: count, broken down by strategy (`--merge` vs `--squash` vs `--rebase`)
- **Closed (CI fail)**: count
- **Closed (conflict)**: count
- **Skipped (pending CI)**: count + a hint that the user can re-run the script later
- **Errors**: count + the raw error per PR

Top-10 repo breakdown by inbound PR count is usually a useful surface — it reveals which projects accumulate the most stale PRs.

## Pitfalls

- **Archived repos block all state changes.** `gh pr close` and `gh pr merge` both fail on archived repos with a clear error. Detect upfront with `gh repo view <repo> --json isArchived` and either skip those PRs or temporarily unarchive (admin only — and visible in the audit log; confirm with the user before doing that on a repo they don't personally own).

- **`gh search` returns substring-matches in titles, not strict-prefix.** Re-filter client-side with `startswith` or a regex anchored at `^`. Trusting the search filter has bitten this skill before — I once took a list of "76 PRs" forward into bulk action and only later discovered the real prefix-match count was different.

- **Pending checks aren't a verdict.** Acting on `PENDING` (either merging or closing) is wrong — wait for CI to finish. Skip + log + tell the user how many were pending so they can re-run later.

- **Mergeable state is a separate signal from CI verdict.** A PR can be CI-green and unmergeable (drift conflicts), or CI-red and mergeable (just won't merge cleanly into a passing main). Don't conflate them in the decision tree.

- **`--admin` bypasses branch protection but not merge-method restrictions.** "Merge commits are not allowed" is a repo-level setting, not a branch protection rule. Use the strategy fallback chain.

- **`--admin` can't fix merge conflicts.** Conflicts mean the diff itself is invalid against base — no permission flag overrides that. The only paths forward are rebase (manual or automated), close, or leave alone. None of these is a "force merge."

- **Notification bursts.** 50+ PR closes/merges in a short window can flood reviewers' inboxes (especially for bot-authored PRs where the bot may take action on close). For runs >100 PRs, offer the user the option to chunk and pause between chunks.

- **Don't act on PRs you don't own.** Contributor PRs in your repo are fine to close (you own the repo). PRs *you opened* in someone else's repo are also fine to close. PRs from third parties to third-party repos that happen to come up in your search results — don't touch them. The `--owner=<user>` filter handles this implicitly; if you broaden the search, re-add the ownership check.

## Worked example

User says: "go through all my open PRs with title starting `[Snyk] Fix` — merge if CI passes, close if CI fails, close if unmergeable."

1. **Discover**: `gh search prs --owner=<user> --state=open 'in:title "[Snyk] Fix"' --json ...` → re-filter with `startswith("[Snyk] Fix")`. Report: "76 PRs across 13 repos."
2. **Confirm**: Show top-10 per-repo distribution + decision rule. Wait for go-ahead.
3. **Apply**: Run the loop. Report final tally:
   - Merged 15 (9 via `--merge`, 6 via `--squash`)
   - Closed 11 (CI failed)
   - Closed 50 (unmergeable due to conflicts)
   - 0 pending, 0 errors
4. **Top-10 surface**: List the repos with the most PRs in this batch — useful for the user to see where their PR queue is concentrated.

## What this skill does NOT do

- It does **not** rebase or auto-resolve merge conflicts. A conflict-blocked PR is treated as a terminal state.
- It does **not** modify PR contents (push commits, edit files, etc.). For that, use `gh-bulk-repo-edit`.
- It does **not** comment on PRs before closing/merging. If the user wants courtesy comments on closed-by-bulk-action PRs, add an extra `gh pr comment` call before the `gh pr close` — but confirm with the user first since extra notifications compound the burst problem.
- It does **not** scale to thousands of PRs in one run. Each PR costs ~3-4 API calls; 5000/hr authenticated rate limit is the ceiling. ~500 PRs per run is comfortable.
