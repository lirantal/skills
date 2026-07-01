---
name: codex-chat-organizer
description: Move existing Codex chats/threads into saved Codex Projects by resolving chat titles and project names, generating a safe move plan, and launching a terminal helper that quits Codex, patches local Codex state after exit, then reopens Codex. Use when the user asks to organize Codex chats by Project, move chats into Projects, re-parent projectless Codex threads, or fix chats appearing outside the intended Project.
---

# Codex Chat Organizer

## Overview

Use this skill to move existing Codex chats into saved Project directories when the Codex UI does not expose a direct move action. The bundled helper performs the fragile state edits only after Codex has fully exited, backs up touched files, verifies the result, and reopens Codex by default.

## Workflow

1. Resolve the user's requested moves with `codex_app.list_threads` and `codex_app.list_projects`.
2. If a chat title or project name is ambiguous, ask the user to choose exact matches before creating a plan.
3. Write a move plan JSON file to `/tmp`.
4. Launch `scripts/launch-chat-organizer.sh <plan.json>` from this skill directory.
5. Tell the user the terminal will ask for one confirmation, then will quit/reopen Codex automatically.

## Move Plan

Create a JSON plan with this shape:

```json
{
  "version": 1,
  "codexHome": "/Users/example/.codex",
  "reopenCodex": true,
  "moves": [
    {
      "threadId": "019f0000-0000-7000-9000-000000000000",
      "threadTitle": "Fix link checker CI",
      "targetProjectName": "GH",
      "targetCwd": "/Users/example/Documents/GH"
    }
  ]
}
```

Rules:

- Use exact thread IDs from `list_threads`; do not guess IDs from titles.
- Use exact project paths from `list_projects`; do not infer project directories from display names.
- Default `codexHome` to `${CODEX_HOME}` when set, otherwise `${HOME}/.codex`.
- Set `reopenCodex` to `true` unless the user asks otherwise.
- Keep the plan in `/tmp` because the external terminal helper must be able to read it after Codex quits.

## Running The Helper

From the skill directory:

```bash
scripts/launch-chat-organizer.sh /tmp/codex-chat-organizer-plan.json
```

Useful options:

- `--dry-run`: open a terminal and print the intended state changes without quitting Codex or editing files.
- `--no-reopen`: apply the move but leave Codex closed.
- `CODEX_CHAT_ORGANIZER_TERMINAL`: set to `terminal`, `iterm`, `wezterm`, or `ghostty` to prefer a terminal. If unset, the launcher checks `~/.codex/chat-organizer-terminal`, then falls back through common macOS terminals.

## Safety Requirements

- Never run the mutating helper while Codex is still alive; the shell wrapper waits for all Codex processes to exit before patching.
- Let the terminal helper ask for confirmation before it quits Codex or writes state.
- Do not bypass a helper error. Missing state files, missing project directories, invalid JSON, failed SQLite backup, or failed verification must stop the move.
- Backups are written under `~/.codex/backups/codex-chat-organizer/<timestamp>/`.

## Validation

Run `scripts/test-fixture.mjs` to exercise the patcher against a temporary Codex home fixture. Run the skill-creator `quick_validate.py` on the skill folder after edits.
