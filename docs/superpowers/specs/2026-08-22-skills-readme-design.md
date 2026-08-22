# Skills repository README design

## Goal

Replace the minimal root README with a user-facing introduction to this repository of personal Codex skills, while preserving the existing Tessl publishing workflow and linking readers to contribution guidance.

## Audience

The primary audience is people discovering, evaluating, and using the skills. Contributors and maintainers should be able to find repository structure, authoring pointers, and publishing instructions without those details dominating the opening.

## Content structure

The README will use this order:

1. **Title and purpose** — identify the repository as a collection of reusable Codex skills and supporting bundles/scripts.
2. **Quick start** — explain that each skill is self-contained in `skills/{skill-name}/SKILL.md`, and show a concrete path from discovering a skill to reading its usage and safety guidance. Avoid claiming an installation mechanism that is not implemented in this repository.
3. **Available skills** — present the six current skills in a compact table with a link and a practical “use it when” description:
   - `codex-chat-organizer`
   - `codex-session-blogger`
   - `gh-bulk-pr-triage`
   - `gh-bulk-repo-edit`
   - `gh-repo-init-context`
   - `writing-style-explainer`
4. **Repository layout** — describe `skills/`, `bundles/`, and `scripts/`.
5. **Publishing to Tessl** — retain the current single-skill and all-skills examples, including patch-bump retry behavior and the `TESSL_PUBLISH_MAX_BUMPS` setting.
6. **Contributing** — link to `CONTRIBUTING.md` and state that each skill should keep its instructions and validation guidance close to its `SKILL.md`.

## Writing and presentation

- Use a concise, practical tone similar to the supplied reference repositories.
- Lead with the repository’s value rather than its internal implementation.
- Put a useful command or file path near the top so a reader can act immediately.
- Use Markdown tables only where they improve scanning; avoid decorative badges or claims not supported by repository files.
- Link directly to each local skill’s `SKILL.md` and to `CONTRIBUTING.md`.

## Scope and constraints

- Update only the root `README.md` for the implementation.
- Do not create an installation CLI, change skill behavior, alter bundle manifests, or modify the publishing helper.
- Do not change the existing `CONTRIBUTING.md` content.
- Preserve accurate existing Tessl commands and behavior.
- Treat the currently untracked `.tessl-plugin` directories as existing user work; do not add, remove, or modify them.

## Acceptance criteria

- A new reader can understand what the repository contains from the opening section.
- A reader can locate every current skill and open its detailed instructions.
- The README explains the role of bundles and scripts.
- The Tessl publishing examples remain runnable and complete.
- Contribution guidance is discoverable through a local link.
- All local Markdown links in the README resolve to files present in the repository.
- The final Markdown is free of placeholders, stale skill names, and unsupported usage claims.
