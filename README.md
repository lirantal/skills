# Skills

Personal Codex skills and related bundles.

## Repository layout

- `skills/` contains individual skills. Each skill lives in its own directory with a `SKILL.md` file.
- `bundles/` contains grouped skill bundles.
- `scripts/` contains local maintenance helpers.

## Publish a skill to Tessl

Use the Tessl publishing helper from the repository root:

```bash
scripts/tessl-publish-skill.sh codex-session-blogger
```

Pass the skill directory name from `skills/`. The helper always imports the skill to the `lirantal` workspace as public, then lints and publishes it:

```bash
tessl skill import "<skill-name>/" --workspace lirantal --public
tessl skill lint "<skill-name>"
tessl skill publish "<skill-name>"
```

For example, this publishes `skills/codex-session-blogger`:

```bash
scripts/tessl-publish-skill.sh codex-session-blogger
```
