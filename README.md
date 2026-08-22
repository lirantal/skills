# Agents Skills

This repository is a personal collection of reusable agent skills, curated bundles, and maintenance helpers. Skills can be installed into your user environment or a project through Microsoft's [Agent Package Manager (APM) quickstart](https://microsoft.github.io/apm/quickstart/).

## Install APM

On macOS or Linux, install APM and verify it is available:

```bash
curl -sSL https://aka.ms/apm-unix | sh
apm --version
```

The official [APM quickstart](https://microsoft.github.io/apm/quickstart/) contains the Windows installation alternative. See the [package installation guide](https://microsoft.github.io/apm/consumer/install-packages/) and [`apm install` reference](https://microsoft.github.io/apm/reference/cli/install/) for more detail.

## Install skills globally

Install one skill for Codex at user scope:

```bash
# Install one skill for Codex at user scope
apm install -g --target codex lirantal/skills --skill gh-repo-init-context
```

Install the full skill collection for Codex at user scope:

```bash
# Install the full skill collection for Codex at user scope
apm install -g --target codex lirantal/skills --skill '*'
```

Here, `-g` means user scope, `--target codex` selects the deployment target, and `--skill` selects a named skill from this multi-skill repository. The wildcard is quoted so the shell passes `*` to APM instead of expanding it against local filenames. `claude` and `agent-skills` are also available as APM targets; individual skills have not necessarily been tested on every runtime.

## Install curated bundles in a project

From a fresh project directory, install the curated bundles you need:

```bash
mkdir my-agent-project
cd my-agent-project

apm install lirantal/skills/bundles/writing --target codex
apm install lirantal/skills/bundles/frontend-design --target codex
```

Project-scope installs update the current project, not your global APM state. Both commands add dependencies to the same `apm.yml`. APM writes `apm.lock.yaml` for reproducibility, so teams should commit both `apm.yml` and `apm.lock.yaml`. The generated `apm_modules/` directory is cache/output and should not be committed.

| Need | Command shape | Result |
| --- | --- | --- |
| One skill for one user | `apm install -g --target codex lirantal/skills --skill gh-repo-init-context` | Installs a selected skill into user scope. |
| All skills for one user | `apm install -g --target codex lirantal/skills --skill '*'` | Installs the full collection into user scope. |
| Curated project setup | `apm install lirantal/skills/bundles/writing --target codex` | Adds a curated bundle to the current project's APM manifest and deploys it. |

## Bundle catalog

| Bundle | Contents |
| --- | --- |
| [`writing`](bundles/writing/apm.yml) | `writing-style-explainer`, `blader/humanizer`, and `jxnl/dots/agents/skills/audit-ai-writing`. |
| [`frontend-design`](bundles/frontend-design/apm.yml) | `anthropics/skills/skills/frontend-design` and `jakubkrehel/make-interfaces-feel-better/skills/make-interfaces-feel-better`. |

Individual skills remain discoverable in their [`SKILL.md`](skills/) files:

- [`codex-chat-organizer`](skills/codex-chat-organizer/SKILL.md)
- [`codex-session-blogger`](skills/codex-session-blogger/SKILL.md)
- [`gh-bulk-pr-triage`](skills/gh-bulk-pr-triage/SKILL.md)
- [`gh-bulk-repo-edit`](skills/gh-bulk-repo-edit/SKILL.md)
- [`gh-repo-init-context`](skills/gh-repo-init-context/SKILL.md)
- [`writing-style-explainer`](skills/writing-style-explainer/SKILL.md)

## Repository layout

```text
skills/   Individual skills; each directory contains a SKILL.md.
bundles/  Grouped skill bundles and their APM manifests.
scripts/  Local maintenance helpers, including Tessl publishing.
```

## Publish a skill to Tessl

Use the Tessl publishing helper from the repository root to publish one skill:

```bash
scripts/tessl-publish-skill.sh codex-session-blogger
```

To publish every skill under `skills/`, use the quoted wildcard:

```bash
scripts/tessl-publish-skill.sh '*'
```

The helper imports the selected skill into the `lirantal` Tessl workspace as public, lints it, and publishes it. If the registry reports that the version already exists, it patch-bumps the Tessl manifest version and retries until publishing succeeds or the retry limit is reached. The default is 20 patch-bump retries after the initial publish attempt; set `TESSL_PUBLISH_MAX_BUMPS` to change it.

The lower-level Tessl commands remain available for maintainers who need them. Run them from the `skills/` directory:

```bash
cd skills
tessl skill import "<skill-name>/" --workspace lirantal --public
tessl skill lint "<skill-name>"
tessl skill publish "<skill-name>"
```

## Contributing

For contribution guidance, see [`CONTRIBUTING.md`](CONTRIBUTING.md). Skill-specific instructions and validation guidance belong next to the skill in its `SKILL.md`.
