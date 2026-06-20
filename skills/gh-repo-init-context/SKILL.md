---
name: gh-repo-init-context
description: Standardize the current GitHub repository's durable project context for coding agents by default. Use when asked to create or update AGENTS.md routing, scaffold or normalize docs/ project documentation, separate consumer README content from contributor/developer docs, or apply a reusable repo documentation convention with root README.md, CONTRIBUTING.md, RELEASE.md, and docs/README.md.
---

# GitHub Repo Init Context

## Goal

Set up a repository so humans and coding agents can quickly discover the project purpose, contribution process, release process, and deeper project-specific development context.

When invoked without additional instructions, treat the request as: inspect the current repository and standardize its `AGENTS.md` and `docs/` project context end to end using this skill's conventions.

Use these conventions unless the user overrides them:

- Keep root `README.md` consumer-facing for GitHub, npm/package pages, and top-level project discovery.
- Keep root `CONTRIBUTING.md` for contribution and PR conventions.
- Keep root `RELEASE.md` for release process; do not create `RELEASING.md`.
- Use `docs/`, not `spec/`, for project documentation.
- Keep `docs/README.md` as the docs index.
- Scaffold `docs/development.md`, `docs/testing.md`, `docs/architecture.md`, and `docs/conventions.md` when absent.
- Keep `docs/features/` when present or useful.
- Do not create `docs/release.md`, `docs/releasing.md`, or `docs/decisions/` by default.

## Workflow

1. Inspect the repo before editing:
   - Use the current repository or workspace root unless the user names another path.
   - `rg --files -g '*.md' -g 'package.json' -g 'pyproject.toml' -g 'Cargo.toml' -g 'go.mod' -g 'Makefile'`
   - Read root `README.md`, `CONTRIBUTING.md`, `RELEASE.md`, any existing `AGENTS.md`, and `docs/README.md` if present.
   - Treat an existing `AGENTS.md` as an input source before replacing or shrinking it. Extract any repo-specific purpose, architecture map, source-path ownership, local commands, testing constraints, generated-file warnings, style rules, docs links, and domain boundaries that are not already preserved elsewhere.
   - Inspect project manifests and test/build scripts enough to write accurate starter docs.

2. Create or update `AGENTS.md`:
   - Read `references/AGENTS.template.md`.
   - Use the template as the default content for a new `AGENTS.md`.
   - Keep the template wording and section order verbatim unless a concrete repo-specific reason requires a targeted edit.
   - If an existing `AGENTS.md` has project rules or context, preserve the information by moving it into the canonical docs before applying the template. Prefer `AGENTS.md` as the stable routing skeleton and keep deeper project-specific details in linked docs.
   - Add links only for existing docs that are important entry points and not already covered by the template.
   - Remove or adjust template links only when the target files will not exist after this skill finishes.
   - Do not add a `Baseline Commands` section by default.
   - Do not duplicate contribution, release, build, test, or style details already owned by linked docs.

3. Create or update `docs/README.md`:
   - Treat it as the docs index, not a second consumer README.
   - Link the canonical docs files and existing useful docs.
   - Preserve links to useful existing docs such as methodology, feature, research, operations, troubleshooting, or legacy development guides.
   - Add short one-line descriptions for each linked document.
   - If `docs/PROJECT.md`, `docs/DEVELOPING.md`, `docs/TESTING.md`, or similar files already exist, normalize names only when the content clearly maps to the canonical filename and links can be updated safely; otherwise keep the file and add it to the index.

4. Scaffold missing canonical docs:
   - `docs/development.md`: setup, local workflows, repository-specific development notes.
   - `docs/testing.md`: test commands, test organization, fixtures, coverage, manual checks.
   - `docs/architecture.md`: module/service map, data/control flow, important boundaries, invariants.
   - `docs/conventions.md`: project-specific coding, naming, documentation, UX/API, and maintenance conventions.
   - Prefer accurate concise starter content from the repo over generic filler. If uncertain, mark a short `TODO` under the relevant heading.
   - When migrating context from an existing `AGENTS.md`, place it where future agents will naturally look:
     - Purpose, product boundary, "not this kind of tool" constraints, module maps, data/control flow, public API surfaces, and important invariants go in `docs/architecture.md`.
     - Setup details, source invocation examples, package-manager quirks, generated output locations, build artifacts, and useful source paths go in `docs/development.md`.
     - Test commands, fixture behavior, temp directories, manual checks, coverage expectations, and when to prefer integration tests go in `docs/testing.md`.
     - Language/runtime requirements, import style, lint/format expectations, generated-file warnings, naming conventions, documentation rules, and maintenance rules go in `docs/conventions.md`.
     - Existing long-form reference docs remain in place and are linked from `docs/README.md`.
   - Before finalizing, compare the old `AGENTS.md` against the new `docs/` files and confirm that no repo-specific instruction or context was silently dropped.

5. Update root `README.md` only when needed:
   - Keep it consumer-facing.
   - Add or refresh a concise documentation link to `docs/README.md` if there is no discoverable path to deeper docs.

6. Validate:
   - Run the repo's markdown lint command if obvious and cheap.
   - Otherwise run a lightweight link/path sanity check manually with `rg`/`find`.
   - For repos with an existing `AGENTS.md`, explicitly sanity-check that migrated details now appear in one of the canonical docs or are already covered by linked existing docs.
   - Report any validation you could not run.

## AGENTS.md Template

Use `references/AGENTS.template.md` as the source of truth for generated `AGENTS.md` content. Copy it verbatim for a fresh repo unless a file it links to will not exist after setup or the user explicitly asks for project-specific additions.

## Reference Prompt

If the user asks for a one-shot prompt instead of applying the skill, read `references/one-shot-prompt.md` and adapt it to their target repo.
