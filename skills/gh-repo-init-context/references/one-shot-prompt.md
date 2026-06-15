# One-Shot Prompt

Use this prompt when a reusable skill is unavailable:

```text
Please standardize this repository's durable project context for humans and coding agents.

Assume the repository already has root README.md, CONTRIBUTING.md, and RELEASE.md. Keep those root filenames. Keep root README.md consumer-facing for GitHub/package pages. Keep CONTRIBUTING.md focused on contribution and PR conventions. Keep RELEASE.md focused on release process.

Use these documentation conventions:

- Use docs/, not spec/, for project documentation.
- Keep docs/README.md as the documentation index.
- Do not create docs/release.md or docs/releasing.md because root RELEASE.md is the release-process source of truth.
- Do not create docs/decisions/ by default.
- Keep docs/features/ if present or useful.
- Prefer lowercase filenames inside docs/.
- Ensure the canonical project docs exist, creating concise starter versions when absent:
  - docs/development.md
  - docs/testing.md
  - docs/architecture.md
  - docs/conventions.md

First inspect the repo's existing markdown files, manifests, scripts, source layout, and tests. Preserve existing documentation content. If docs/ already exists, either add existing docs to docs/README.md and AGENTS.md routing, or normalize names only when the mapping is obvious and links can be safely updated.

Create or update AGENTS.md from this template. Use it verbatim for a fresh repo unless a linked file will not exist after setup, or unless the repo has existing AGENTS.md content that must be preserved.

```md
# AGENTS.md

Guidance for AI coding agents working in this repository.

## Start Here

Before making changes, read:

- `CONTRIBUTING.md` for contribution, PR, testing, commit, and agent-specific expectations.
- `RELEASE.md` for release workflow details.
- `README.md` for user-facing behavior, install/use examples, and package or app overview.
- `docs/README.md` for the project documentation index.
- `docs/development.md` for local setup and development workflows.
- `docs/testing.md` for test strategy, commands, and verification expectations.
- `docs/architecture.md` for project structure, boundaries, and important invariants.
- `docs/conventions.md` for project-specific coding, documentation, and maintenance conventions.

Treat those files as the source of truth. Do not duplicate or reinterpret their rules here.

## Documentation

- Keep documentation in sync when changing behavior, public interfaces, workflows, architecture, configuration, or operational assumptions.
- Put project-specific development details in `docs/`; keep root files focused on their standard audiences.
- Prefer linking to the source of truth over duplicating long instructions across files.
- When adding new docs, link them from `docs/README.md` and update this file only when they become important entry points for future agents.

## PRs and Issues

- Follow PR, issue, and agent-labeling rules in `CONTRIBUTING.md`.
- Use the issue-linking format specified in `CONTRIBUTING.md`.

## Releases

- Follow `RELEASE.md` for release workflow and changeset creation steps.
- If this project uses changesets, treat `RELEASE.md` and any changeset guidance in `CONTRIBUTING.md` as authoritative.
```

Do not add a Baseline Commands section to AGENTS.md. Do not duplicate contribution, release, build, test, or style details that belong in the linked docs.

Update docs/README.md as the docs index with one-line descriptions for each linked document. Update root README.md only if needed to add a concise link to docs/README.md.

After editing, run the repo's markdown lint command if obvious and cheap; otherwise perform a lightweight path/link sanity check and report what was validated.
```
