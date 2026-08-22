# Codex skills

This repository contains reusable personal Codex skills, grouped bundles, and local maintenance helpers. Each skill is self-contained under `skills/`; its `SKILL.md` describes when it applies, its workflow, safety notes, and validation guidance.

To inspect a skill, open its `SKILL.md`:

```bash
sed -n '1,240p' skills/gh-repo-init-context/SKILL.md
```

Open the relevant `SKILL.md` to understand when the skill applies and how to use it.

## Skill catalog

| Skill | Use it when |
| --- | --- |
| [`codex-chat-organizer`](skills/codex-chat-organizer/SKILL.md) | You need to move Codex chats or threads into saved Codex Projects. |
| [`codex-session-blogger`](skills/codex-session-blogger/SKILL.md) | You want to turn a Codex session, implementation, investigation, or review into a publishable technical article. |
| [`gh-bulk-pr-triage`](skills/gh-bulk-pr-triage/SKILL.md) | You need to triage many open GitHub pull requests using CI and mergeability rules. |
| [`gh-bulk-repo-edit`](skills/gh-bulk-repo-edit/SKILL.md) | You need to apply the same surgical edit across many GitHub repositories. |
| [`gh-repo-init-context`](skills/gh-repo-init-context/SKILL.md) | You need to establish or normalize durable project context and documentation in a GitHub repository. |
| [`writing-style-explainer`](skills/writing-style-explainer/SKILL.md) | You need guidance for writing clear, structured explainer articles. |

## Repository layout

```text
skills/   Individual skills; each directory contains a SKILL.md.
bundles/  Grouped skill bundles and their APM manifests.
scripts/  Local maintenance helpers, including Tessl publishing.
```

For contribution guidance, see [`CONTRIBUTING.md`](CONTRIBUTING.md). Skill-specific instructions and validation guidance belong next to the skill in its `SKILL.md`.

## Publish a skill to Tessl

Use the Tessl publishing helper from the repository root to publish one skill:

```bash
scripts/tessl-publish-skill.sh codex-session-blogger
```

To publish every skill under `skills/`, use the quoted wildcard:

```bash
scripts/tessl-publish-skill.sh '*'
```

The helper imports the selected skill into the `lirantal` Tessl workspace as public, lints it, and publishes it. If the registry reports that the version already exists, it patch-bumps the Tessl manifest version and retries until publishing succeeds or the retry limit is reached. The default limit is 20 attempts; set `TESSL_PUBLISH_MAX_BUMPS` to change it.

The lower-level Tessl commands remain available for maintainers who need them:

```bash
tessl skill import "<skill-name>/" --workspace lirantal --public
tessl skill lint "<skill-name>"
tessl skill publish "<skill-name>"
```
