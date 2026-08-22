# Agents Skills README design

## Goal

Rework the root README so it presents this repository as a personal collection of general-purpose agent skills and curated bundles, with APM installation and usage as the primary user workflow. Keep the existing repository layout and Tessl publishing guidance because both are useful maintainer references.

## Audience and identity

The primary audience is someone who wants to install one or more of these skills into an agent runtime or project. The repository should be described as **Agents Skills**, not as a Codex-specific repository. Codex remains one supported APM target and the main worked target for the examples, alongside other runtimes supported by APM.

## Content structure

The README will use this order:

1. **Title and purpose** — describe the private collection of reusable agent skills, curated bundles, and maintenance helpers.
2. **Install APM** — link to Microsoft's official APM documentation and show the macOS/Linux installer plus `apm --version`.
3. **Install one skill globally** — show a concrete user-scope Codex command using the repository's remote skill bundle and `--skill` selector:

   ```bash
   apm install -g --target codex lirantal/skills --skill gh-repo-init-context
   ```

4. **Install the full collection globally** — show the quoted wildcard form:

   ```bash
   apm install -g --target codex lirantal/skills --skill '*'
   ```

5. **Install a curated bundle into a project** — explain that APM writes or updates `apm.yml` and `apm.lock.yaml` for project installs, then show both existing bundle references:

   ```bash
   apm install lirantal/skills/bundles/writing --target codex
   apm install lirantal/skills/bundles/frontend-design --target codex
   ```

6. **Choose a target and install scope** — explain `--target codex`, `--target claude`, and `--target agent-skills`, plus the difference between `--global` user scope and project scope. Explain that a target can be changed in the examples without changing the package reference.
7. **Available bundles** — document `writing` and `frontend-design`, including the dependencies declared by each `apm.yml`.
8. **Repository layout** — retain the accurate `skills/`, `bundles/`, and `scripts/` explanation.
9. **Reproducible project installs** — explain committing `apm.yml` and `apm.lock.yaml`, not the APM cache, and using `apm install` for collaborators or CI.
10. **Publish a skill to Tessl** — retain the current helper commands, lower-level Tessl commands, and patch-bump retry behavior.
11. **Contributing** — link to `CONTRIBUTING.md`.

## APM usage details

- Use `apm install -g --target codex ...` for user-level installation; `-g` is the documented APM global-scope flag.
- Use `--skill {skill-name}` to select a single skill from the repository's multi-skill bundle, and quote `'*'` when selecting the full collection in a shell.
- Use the `bundles/{bundle-name}` virtual subdirectory references for the curated meta-packages. The repository intentionally uses `bundles/` rather than `collections/` because APM reserves or special-cases the latter.
- Use explicit `--target codex` in examples so they work in a project without detectable Codex markers. Mention that APM also supports other targets, without claiming this repository has been tested on every target.
- Explain that project installs update the manifest and lockfile, while `apm_modules/` is cache/output that should not be committed.
- Link to the official [APM quickstart](https://microsoft.github.io/apm/quickstart/), [package installation guide](https://microsoft.github.io/apm/consumer/install-packages/), and [`apm install` reference](https://microsoft.github.io/apm/reference/cli/install/).

## Bundle catalog

| Bundle | Contents |
| --- | --- |
| [`writing`](bundles/writing/apm.yml) | The local `writing-style-explainer` skill plus `blader/humanizer` and `jxnl/dots/agents/skills/audit-ai-writing`. |
| [`frontend-design`](bundles/frontend-design/apm.yml) | `anthropics/skills/skills/frontend-design` plus `jakubkrehel/make-interfaces-feel-better/skills/make-interfaces-feel-better`. |

## Writing and presentation

- Lead with the general “Agents Skills” identity and APM installation, not Codex or Tessl.
- Put copy-pasteable commands near the top, with explicit working-directory assumptions.
- Keep bundle and skill names linked to the files that define them.
- Explain the global/project distinction in plain language before the detailed reference sections.
- Use official Microsoft APM links for current CLI semantics instead of duplicating every flag.
- Preserve the existing Tessl publishing behavior and examples, but keep it secondary to APM usage.
- Avoid claiming that every skill or bundle supports every agent runtime; describe target flexibility as an APM capability.

## Scope and constraints

- Modify only the root `README.md` for the implementation.
- Do not change skill content, bundle manifests, the Tessl publishing helper, or `CONTRIBUTING.md`.
- Preserve the existing repository layout section and Tessl publishing section unless wording must change to integrate them into the new structure.
- Leave the existing untracked `.tessl-plugin` directories untouched.
- Keep commands accurate for the repository's current layout and the installed APM CLI behavior.

## Acceptance criteria

- The README calls the repository “Agents Skills” and describes it as a personal collection, not a Codex-only repository.
- A new user can find the APM installation command and verify APM is installed.
- The README contains accurate copy-pasteable commands for installing one skill globally, the full collection globally, and both curated bundles into a project.
- The README explains `--global`, `--target`, `--skill`, project manifests, and lockfiles well enough for a user to choose the right workflow.
- Both existing bundles are cataloged and linked to their manifests.
- The repository layout and Tessl publishing guidance remain discoverable and accurate.
- All local Markdown links in the README resolve to files present in the repository.
- The final README has no unsupported runtime claims, stale skill names, or placeholder text.
