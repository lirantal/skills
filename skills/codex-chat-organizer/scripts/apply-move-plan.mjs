#!/usr/bin/env node
import { copyFileSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, statSync, writeFileSync } from "node:fs";
import { basename, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

const CODEX_PROCESS_PATTERN = String.raw`Codex \(Renderer\)|Codex \(Service\)|/Applications/Codex.app/Contents/MacOS/Codex`;

function usage() {
  console.log("Usage: apply-move-plan.mjs --plan <plan.json> [--dry-run] [--allow-running]");
}

function parseArgs(argv) {
  const args = { dryRun: false, allowRunning: false, planPath: "" };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--dry-run") args.dryRun = true;
    else if (arg === "--allow-running") args.allowRunning = true;
    else if (arg === "--plan") {
      args.planPath = argv[i + 1] || "";
      i += 1;
    } else if (!args.planPath && !arg.startsWith("--")) {
      args.planPath = arg;
    } else if (arg === "--help" || arg === "-h") {
      usage();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if (!args.planPath) throw new Error("Missing --plan <plan.json>");
  return args;
}

function readJson(filePath) {
  try {
    return JSON.parse(readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not parse JSON at ${filePath}: ${error.message}`);
  }
}

function sqlQuote(value) {
  return `'${String(value).replaceAll("'", "''")}'`;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...options });
  if (result.status !== 0) {
    const detail = [result.stderr, result.stdout].filter(Boolean).join("\n").trim();
    throw new Error(`${command} ${args.join(" ")} failed${detail ? `:\n${detail}` : ""}`);
  }
  return result.stdout;
}

function checkTool(name) {
  const result = spawnSync("command", ["-v", name], { shell: true, encoding: "utf8" });
  if (result.status !== 0) throw new Error(`Required command not found: ${name}`);
}

function codexIsRunning() {
  const result = spawnSync("pgrep", ["-f", CODEX_PROCESS_PATTERN], { stdio: "ignore" });
  return result.status === 0;
}

function validatePlan(plan) {
  if (plan.version !== 1) throw new Error("Unsupported plan.version; expected 1");
  if (!plan.codexHome || typeof plan.codexHome !== "string") throw new Error("plan.codexHome must be a string");
  if (!Array.isArray(plan.moves) || plan.moves.length === 0) throw new Error("plan.moves must be a non-empty array");

  const seen = new Set();
  for (const [index, move] of plan.moves.entries()) {
    const label = `moves[${index}]`;
    if (!move.threadId || typeof move.threadId !== "string") throw new Error(`${label}.threadId must be a string`);
    if (!move.targetCwd || typeof move.targetCwd !== "string") throw new Error(`${label}.targetCwd must be a string`);
    if (!existsSync(move.targetCwd) || !statSync(move.targetCwd).isDirectory()) {
      throw new Error(`${label}.targetCwd does not exist or is not a directory: ${move.targetCwd}`);
    }
    if (seen.has(move.threadId)) throw new Error(`Duplicate threadId in plan: ${move.threadId}`);
    seen.add(move.threadId);
  }
}

function workspacePolicy(targetCwd) {
  return {
    type: "workspaceWrite",
    writableRoots: [targetCwd],
    networkAccess: false,
    excludeTmpdirEnvVar: false,
    excludeSlashTmp: false,
  };
}

function managedSandboxPolicy(targetCwd) {
  return {
    type: "managed",
    file_system: {
      type: "restricted",
      entries: [
        { path: { type: "special", value: { kind: "root" } }, access: "read" },
        { path: { type: "path", path: targetCwd }, access: "write" },
        { path: { type: "special", value: { kind: "slash_tmp" } }, access: "write" },
        { path: { type: "special", value: { kind: "tmpdir" } }, access: "write" },
        { path: { type: "path", path: join(targetCwd, ".git") }, access: "read" },
        { path: { type: "path", path: join(targetCwd, ".agents") }, access: "read" },
        { path: { type: "path", path: join(targetCwd, ".codex") }, access: "read" },
      ],
    },
    network: "restricted",
  };
}

function queryThreadCwds(stateDb, moves) {
  const result = new Map();
  for (const move of moves) {
    const sql = `SELECT cwd FROM threads WHERE id = ${sqlQuote(move.threadId)} LIMIT 1;`;
    const cwd = run("sqlite3", ["-noheader", "-batch", stateDb, sql]).trim();
    result.set(move.threadId, cwd || "");
  }
  return result;
}

function recursiveJsonlFiles(rootDir) {
  const files = [];
  if (!existsSync(rootDir)) return files;
  const stack = [rootDir];
  while (stack.length > 0) {
    const current = stack.pop();
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const fullPath = join(current, entry.name);
      if (entry.isDirectory()) stack.push(fullPath);
      else if (entry.isFile() && entry.name.endsWith(".jsonl")) files.push(fullPath);
    }
  }
  return files;
}

function findTranscriptFiles(codexHome, moves) {
  const ids = new Set(moves.map((move) => move.threadId));
  const roots = [join(codexHome, "sessions"), join(codexHome, "archived_sessions")];
  const matches = new Map([...ids].map((id) => [id, []]));
  for (const root of roots) {
    for (const filePath of recursiveJsonlFiles(root)) {
      for (const id of ids) {
        if (basename(filePath).includes(id)) matches.get(id).push(filePath);
      }
    }
  }
  return matches;
}

function replacePath(value, oldPath, newPath) {
  if (!oldPath || oldPath === newPath) return value;
  if (typeof value === "string") return value.split(oldPath).join(newPath);
  if (Array.isArray(value)) return value.map((item) => replacePath(item, oldPath, newPath));
  if (value && typeof value === "object") {
    for (const key of Object.keys(value)) value[key] = replacePath(value[key], oldPath, newPath);
  }
  return value;
}

function inspectTranscript(filePath, threadId) {
  const original = readFileSync(filePath, "utf8");
  const lines = original.endsWith("\n") ? original.slice(0, -1).split("\n") : original.split("\n");
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const event = JSON.parse(line);
      if (event.type === "session_meta" && event.payload?.id === threadId && typeof event.payload.cwd === "string") {
        return event.payload.cwd;
      }
    } catch {
      continue;
    }
  }
  return "";
}

function patchTranscript(filePath, move, fallbackOldPath) {
  const oldFromTranscript = inspectTranscript(filePath, move.threadId);
  const oldPath = oldFromTranscript || fallbackOldPath;
  const original = readFileSync(filePath, "utf8");
  const trailingNewline = original.endsWith("\n");
  const lines = trailingNewline ? original.slice(0, -1).split("\n") : original.split("\n");
  const patchedLines = lines.map((line) => {
    if (!line.trim()) return line;
    const event = JSON.parse(line);

    if (event.type === "session_meta" && event.payload?.id === move.threadId) {
      event.payload.cwd = move.targetCwd;
    }

    if (event.type === "turn_context" && event.payload) {
      replacePath(event.payload, oldPath, move.targetCwd);
    }

    if (event.type === "response_item" && event.payload?.type === "message") {
      for (const part of event.payload.content || []) {
        if (
          part.type === "input_text" &&
          typeof part.text === "string" &&
          part.text.includes("<environment_context>") &&
          oldPath
        ) {
          part.text = part.text.split(oldPath).join(move.targetCwd);
        }
      }
    }

    return JSON.stringify(event);
  });
  const patched = patchedLines.join("\n") + (trailingNewline ? "\n" : "");
  return { patched, changed: patched !== original, oldPath };
}

function patchGlobalState(stateJsonPath, moves, dryRun) {
  const state = readJson(stateJsonPath);
  const ids = new Set(moves.map((move) => move.threadId));
  const beforeProjectless = Array.isArray(state["projectless-thread-ids"])
    ? state["projectless-thread-ids"].filter((id) => ids.has(id)).length
    : 0;

  if (!dryRun) {
    if (Array.isArray(state["projectless-thread-ids"])) {
      state["projectless-thread-ids"] = state["projectless-thread-ids"].filter((id) => !ids.has(id));
    }
    if (!state["thread-workspace-root-hints"] || typeof state["thread-workspace-root-hints"] !== "object") {
      state["thread-workspace-root-hints"] = {};
    }
    for (const move of moves) {
      state["thread-workspace-root-hints"][move.threadId] = move.targetCwd;
      if (state["thread-projectless-output-directories"]) {
        delete state["thread-projectless-output-directories"][move.threadId];
      }
      const permissions = state["electron-persisted-atom-state"]?.["heartbeat-thread-permissions-by-id"];
      if (permissions?.[move.threadId]) {
        permissions[move.threadId].sandboxPolicy = workspacePolicy(move.targetCwd);
      }
    }
    const tmpPath = `${stateJsonPath}.${process.pid}.tmp`;
    writeFileSync(tmpPath, JSON.stringify(state, null, 2) + "\n");
    renameSync(tmpPath, stateJsonPath);
  }

  return { beforeProjectless };
}

function patchDatabase(stateDb, moves, dryRun) {
  if (dryRun) return;
  const statements = [];
  for (const move of moves) {
    statements.push(
      `UPDATE threads SET cwd = ${sqlQuote(move.targetCwd)}, sandbox_policy = ${sqlQuote(JSON.stringify(managedSandboxPolicy(move.targetCwd)))} WHERE id = ${sqlQuote(move.threadId)};`,
    );
  }
  statements.push("PRAGMA wal_checkpoint(FULL);");
  run("sqlite3", ["-batch", stateDb], { input: statements.join("\n") });
}

function verify(stateJsonPath, stateDb, moves) {
  const state = readJson(stateJsonPath);
  const projectless = state["projectless-thread-ids"] || [];
  const dbCwds = queryThreadCwds(stateDb, moves);
  const failures = [];

  for (const move of moves) {
    if (projectless.includes(move.threadId)) failures.push(`${move.threadId} is still projectless`);
    if (state["thread-workspace-root-hints"]?.[move.threadId] !== move.targetCwd) {
      failures.push(`${move.threadId} has unexpected workspace hint`);
    }
    if (dbCwds.get(move.threadId) !== move.targetCwd) {
      failures.push(`${move.threadId} has unexpected database cwd: ${dbCwds.get(move.threadId) || "<missing>"}`);
    }
  }

  if (failures.length > 0) throw new Error(`Verification failed:\n- ${failures.join("\n- ")}`);
}

function backupTouchedFiles({ stateJsonPath, stateDb, backupDir, transcriptsById, moves }) {
  mkdirSync(backupDir, { recursive: true });
  copyFileSync(stateJsonPath, join(backupDir, ".codex-global-state.json.bak"));
  run("sqlite3", [stateDb, "PRAGMA wal_checkpoint(FULL);"]);
  run("sqlite3", [stateDb, `.backup '${join(backupDir, "state_5.sqlite.bak").replaceAll("'", "''")}'`]);

  for (const move of moves) {
    for (const transcript of transcriptsById.get(move.threadId) || []) {
      copyFileSync(transcript, join(backupDir, `${move.threadId}-${basename(transcript)}.bak`));
    }
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const planPath = resolve(args.planPath);
  const plan = readJson(planPath);
  validatePlan(plan);

  checkTool("sqlite3");
  if (!args.dryRun && !args.allowRunning && codexIsRunning()) {
    throw new Error("Codex is still running. Refusing to patch live state.");
  }

  const codexHome = resolve(plan.codexHome);
  const stateJsonPath = join(codexHome, ".codex-global-state.json");
  const stateDb = join(codexHome, "state_5.sqlite");
  if (!existsSync(stateJsonPath)) throw new Error(`Missing Codex global state: ${stateJsonPath}`);
  if (!existsSync(stateDb)) throw new Error(`Missing Codex SQLite state: ${stateDb}`);

  const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
  const backupDir = join(codexHome, "backups", "codex-chat-organizer", stamp);
  const currentCwds = queryThreadCwds(stateDb, plan.moves);
  const transcriptsById = findTranscriptFiles(codexHome, plan.moves);

  console.log(`Plan: ${planPath}`);
  console.log(`Codex home: ${codexHome}`);
  console.log(`Moves: ${plan.moves.length}`);
  for (const move of plan.moves) {
    const title = move.threadTitle ? ` (${move.threadTitle})` : "";
    const project = move.targetProjectName ? ` -> ${move.targetProjectName}` : "";
    const current = currentCwds.get(move.threadId) || "<missing>";
    const transcriptCount = (transcriptsById.get(move.threadId) || []).length;
    console.log(`- ${move.threadId}${title}${project}`);
    console.log(`  cwd: ${current} -> ${move.targetCwd}`);
    console.log(`  transcripts: ${transcriptCount}`);
  }

  if (args.dryRun) {
    console.log("Dry run only. No files changed.");
    return;
  }

  console.log(`Backup directory: ${backupDir}`);
  backupTouchedFiles({ stateJsonPath, stateDb, backupDir, transcriptsById, moves: plan.moves });

  const globalSummary = patchGlobalState(stateJsonPath, plan.moves, false);
  console.log(`Global state patched; removed ${globalSummary.beforeProjectless} projectless entries.`);

  patchDatabase(stateDb, plan.moves, false);
  console.log("SQLite state patched.");

  let changedTranscripts = 0;
  for (const move of plan.moves) {
    const fallbackOldPath = currentCwds.get(move.threadId);
    for (const transcript of transcriptsById.get(move.threadId) || []) {
      const { patched, changed } = patchTranscript(transcript, move, fallbackOldPath);
      if (changed) {
        writeFileSync(transcript, patched);
        changedTranscripts += 1;
      }
    }
  }
  console.log(`Transcripts patched: ${changedTranscripts}`);

  verify(stateJsonPath, stateDb, plan.moves);
  console.log("Verification passed.");
}

try {
  main();
} catch (error) {
  console.error(`ERROR: ${error.message}`);
  process.exit(1);
}
