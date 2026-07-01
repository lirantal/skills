#!/usr/bin/env node
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed:\n${result.stderr || result.stdout}`);
  }
  return result.stdout;
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

const root = mkdtempSync(join(tmpdir(), "codex-chat-organizer-test-"));
const codexHome = join(root, ".codex");
const project = join(root, "Project A");
const oldCwd = join(root, "old-thread");
const threadId = "019f0000-0000-7000-9000-000000000001";

try {
  mkdirSync(codexHome, { recursive: true });
  mkdirSync(project, { recursive: true });
  mkdirSync(oldCwd, { recursive: true });
  mkdirSync(join(codexHome, "sessions", "2026", "06", "30"), { recursive: true });

  writeFileSync(
    join(codexHome, ".codex-global-state.json"),
    JSON.stringify(
      {
        "projectless-thread-ids": [threadId],
        "thread-workspace-root-hints": {},
        "thread-projectless-output-directories": { [threadId]: oldCwd },
        "electron-persisted-atom-state": {
          "heartbeat-thread-permissions-by-id": {
            [threadId]: { sandboxPolicy: { type: "workspaceWrite", writableRoots: [oldCwd] } },
          },
        },
      },
      null,
      2,
    ) + "\n",
  );

  const db = join(codexHome, "state_5.sqlite");
  run("sqlite3", [
    db,
    `CREATE TABLE threads (id TEXT PRIMARY KEY, cwd TEXT, sandbox_policy TEXT);
     INSERT INTO threads (id, cwd, sandbox_policy) VALUES ('${threadId}', '${oldCwd}', '{}');`,
  ]);

  const transcript = join(codexHome, "sessions", "2026", "06", "30", `rollout-2026-06-30T00-00-00-${threadId}.jsonl`);
  writeFileSync(
    transcript,
    [
      JSON.stringify({ type: "session_meta", payload: { id: threadId, cwd: oldCwd } }),
      JSON.stringify({ type: "turn_context", payload: { cwd: oldCwd, notes: [`path ${oldCwd}`] } }),
      JSON.stringify({ type: "response_item", payload: { type: "message", content: [{ type: "input_text", text: `<environment_context>${oldCwd}</environment_context>` }] } }),
    ].join("\n") + "\n",
  );

  const plan = join(root, "plan.json");
  writeFileSync(
    plan,
    JSON.stringify(
      {
        version: 1,
        codexHome,
        reopenCodex: false,
        moves: [{ threadId, threadTitle: "Fixture thread", targetProjectName: "Project A", targetCwd: project }],
      },
      null,
      2,
    ) + "\n",
  );

  run("node", [join(fileURLToPath(new URL(".", import.meta.url)), "apply-move-plan.mjs"), "--plan", plan, "--allow-running"]);

  const state = JSON.parse(readFileSync(join(codexHome, ".codex-global-state.json"), "utf8"));
  assert(!state["projectless-thread-ids"].includes(threadId), "thread remained projectless");
  assert(state["thread-workspace-root-hints"][threadId] === project, "workspace hint was not updated");
  assert(!state["thread-projectless-output-directories"][threadId], "projectless output directory was not removed");

  const cwd = run("sqlite3", ["-noheader", db, `SELECT cwd FROM threads WHERE id = '${threadId}';`]).trim();
  assert(cwd === project, "database cwd was not updated");
  assert(readFileSync(transcript, "utf8").includes(project), "transcript was not patched");
  assert(!readFileSync(transcript, "utf8").includes(oldCwd), "old cwd remained in transcript");

  console.log("Fixture test passed.");
} finally {
  if (process.env.CODEX_CHAT_ORGANIZER_KEEP_TEST_DIR) {
    console.log(`Keeping fixture at ${root}`);
  } else {
    rmSync(root, { recursive: true, force: true });
  }
}
