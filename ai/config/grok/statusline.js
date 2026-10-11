#!/usr/bin/env node
"use strict";

/**
 * Grok status line. Node only, no npm dependencies.
 *
 * repo | git | model | context | idle | cache | worktree diff | duration | cost
 *
 * Quota windows, a pull request, and thinking/fast flags are not in Grok's
 * payload, so this row does not invent them.
 */

const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", main);

function main() {
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  const RESET = "\x1b[0m";
  const BOLD = "\x1b[1m";
  const TEXT = "\x1b[38;2;218;222;231m";
  const MUTED = "\x1b[38;2;145;151;166m";
  const FAINT = "\x1b[38;2;82;88;101m";
  const CYAN = "\x1b[38;2;78;201;240m";
  const BLUE = "\x1b[38;2;105;180;255m";
  const PURPLE = "\x1b[38;2;203;166;247m";
  const GREEN = "\x1b[38;2;93;214;136m";
  const YELLOW = "\x1b[38;2;244;205;108m";
  const ORANGE = "\x1b[38;2;247;148;83m";
  const RED = "\x1b[38;2;255;107;122m";
  const SEP = `${FAINT} │ ${RESET}`;

  const asInt = (value) => {
    const n = Number(value);
    return Number.isFinite(n) ? Math.trunc(n) : null;
  };

  const fmtCount = (n) => {
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
    if (n >= 1_000) return `${(n / 1_000).toFixed(1).replace(/\.0$/, "")}k`;
    return String(n);
  };

  const fmtDuration = (seconds) => {
    seconds = Math.max(0, seconds);
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) {
      const m = Math.floor(seconds / 60);
      const s = seconds % 60;
      return `${m}m${String(s).padStart(2, "0")}s`;
    }
    if (seconds < 86400) {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      return `${h}h${String(m).padStart(2, "0")}m`;
    }
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    return `${d}d${String(h).padStart(2, "0")}h`;
  };

  const truncate = (value, max) => {
    const s = String(value ?? "");
    return s.length <= max ? s : `${s.slice(0, max - 1)}…`;
  };

  const visibleLength = (value) => value.replace(/\x1b\[[0-9;]*m/g, "").length;

  const runGit = (args, cwd) => {
    try {
      return execFileSync("git", ["-C", cwd, ...args], {
        encoding: "utf8",
        stdio: ["ignore", "pipe", "ignore"],
        windowsHide: true,
        timeout: 2500,
      }).trimEnd();
    } catch {
      return "";
    }
  };

  let cwd = data?.workspace?.current_dir || data?.cwd || process.cwd();
  if (!fs.existsSync(cwd)) cwd = process.cwd();

  const sessionId = String(data?.session_id || "default").replace(/[^A-Za-z0-9._-]/g, "_");
  const nowEpoch = Math.floor(Date.now() / 1000);
  const cols = asInt(process.env.COLUMNS) ?? 80;

  const stateRoot = path.join(process.env.LOCALAPPDATA || os.tmpdir(), "Grok", "statusline");
  try {
    fs.mkdirSync(stateRoot, { recursive: true });
  } catch {
    /* the row still renders without a cache */
  }

  const repoName =
    data?.workspace?.repo?.name ||
    (data?.workspace?.repo_root ? path.basename(data.workspace.repo_root) : "") ||
    path.basename(runGit(["rev-parse", "--show-toplevel"], cwd) || cwd);
  const repoSeg = `${BOLD}${CYAN}◆ ${truncate(repoName, 28)}${RESET}`;

  const gitCachePath = path.join(stateRoot, `git-${sessionId}.json`);
  let gitSnapshot = null;
  try {
    const stat = fs.statSync(gitCachePath);
    if ((Date.now() - stat.mtimeMs) / 1000 < 10) {
      gitSnapshot = JSON.parse(fs.readFileSync(gitCachePath, "utf8"));
    }
  } catch {
    gitSnapshot = null;
  }

  if (!gitSnapshot) {
    const status = runGit(["status", "--porcelain=v1", "--branch"], cwd);
    let branch = data?.workspace?.branch || "no-git";
    let staged = 0;
    let modified = 0;
    let untracked = 0;
    let ahead = 0;
    let behind = 0;
    if (status) {
      for (const line of status.split(/\r?\n/)) {
        if (!line) continue;
        if (line.startsWith("## ")) {
          const header = line.slice(3);
          if (header.startsWith("HEAD (no branch)") || header.startsWith("HEAD (detached")) {
            const sha = runGit(["rev-parse", "--short", "HEAD"], cwd);
            branch = sha ? `detached@${sha}` : "detached";
          } else if (header.startsWith("No commits yet on ")) {
            branch = header.slice("No commits yet on ".length);
          } else if (header.startsWith("Initial commit on ")) {
            branch = header.slice("Initial commit on ".length);
          } else {
            branch = header.split("...")[0].split(" ")[0];
          }
          const aheadMatch = line.match(/ahead\s+(\d+)/);
          const behindMatch = line.match(/behind\s+(\d+)/);
          if (aheadMatch) ahead = Number(aheadMatch[1]);
          if (behindMatch) behind = Number(behindMatch[1]);
          continue;
        }
        if (line.startsWith("??")) {
          untracked += 1;
          continue;
        }
        if (line.length >= 2) {
          if (line[0] !== " " && line[0] !== "?") staged += 1;
          if (line[1] !== " ") modified += 1;
        }
      }
    }

    let added = 0;
    let removed = 0;
    for (const args of [
      ["diff", "--numstat"],
      ["diff", "--cached", "--numstat"],
    ]) {
      const blob = runGit(args, cwd);
      if (!blob) continue;
      for (const line of blob.split(/\r?\n/)) {
        const [plus, minus] = line.split("\t");
        if (/^\d+$/.test(plus)) added += Number(plus);
        if (/^\d+$/.test(minus)) removed += Number(minus);
      }
    }

    gitSnapshot = { branch, staged, modified, untracked, ahead, behind, added, removed };
    try {
      fs.writeFileSync(gitCachePath, JSON.stringify(gitSnapshot));
    } catch {
      /* uncached next run is fine */
    }
  }

  let gitSeg = `${PURPLE} ${truncate(gitSnapshot.branch || "no-git", 27)}${RESET}`;
  if (gitSnapshot.staged > 0) gitSeg += ` ${GREEN}+${gitSnapshot.staged}${RESET}`;
  if (gitSnapshot.modified > 0) gitSeg += ` ${YELLOW}~${gitSnapshot.modified}${RESET}`;
  if (gitSnapshot.untracked > 0) gitSeg += ` ${MUTED}?${gitSnapshot.untracked}${RESET}`;
  if (gitSnapshot.ahead > 0) gitSeg += ` ${GREEN}↑${gitSnapshot.ahead}${RESET}`;
  if (gitSnapshot.behind > 0) gitSeg += ` ${ORANGE}↓${gitSnapshot.behind}${RESET}`;

  const effort = String(data?.effort?.level || "");
  const effortShort = { low: "L", medium: "M", high: "H", xhigh: "X", max: "MAX" }[effort] || "";
  let modelText = truncate(data?.model?.display_name || data?.model?.id || "?", 24);
  if (effortShort) modelText += `/${effortShort}`;
  const modelColor = effort === "xhigh" || effort === "max" ? `${BOLD}${RED}` : effort === "high" ? `${BOLD}${PURPLE}` : PURPLE;
  const modelSeg = `${modelColor}${modelText}${RESET}`;

  const ctxTokens = asInt(data?.context_window?.context_tokens);
  const ctxSize = asInt(data?.context_window?.context_window_size);
  let ctxPct = asInt(data?.context_window?.used_percentage);
  if (ctxPct == null && ctxTokens != null && ctxSize) ctxPct = Math.round((ctxTokens * 100) / ctxSize);
  let ctxSeg = "";
  if (ctxPct != null || (ctxTokens != null && ctxSize)) {
    const pct = ctxPct ?? 0;
    const ctxColor = pct >= 90 ? `${BOLD}${RED}` : pct >= 80 ? ORANGE : pct >= 65 ? YELLOW : GREEN;
    ctxSeg =
      ctxTokens != null && ctxSize
        ? `${ctxColor}ctx ${fmtCount(ctxTokens)}${RESET}${FAINT}/${RESET}${ctxColor}${fmtCount(ctxSize)} ${pct}%${RESET}`
        : `${ctxColor}ctx ${pct}%${RESET}`;
  }

  const promptId = data?.prompt_id ? String(data.prompt_id) : "";
  const idlePath = path.join(stateRoot, `idle-${sessionId}.json`);
  let idleState = { prompt_id: "", last_prompt_epoch: 0 };
  try {
    idleState = JSON.parse(fs.readFileSync(idlePath, "utf8"));
  } catch {
    idleState = { prompt_id: "", last_prompt_epoch: 0 };
  }
  if (promptId && promptId !== idleState.prompt_id) {
    idleState = { prompt_id: promptId, last_prompt_epoch: nowEpoch };
    try {
      fs.writeFileSync(idlePath, JSON.stringify(idleState));
    } catch {
      /* idle stays blank this run */
    }
  }
  const lastPrompt = asInt(idleState.last_prompt_epoch) ?? 0;
  let idleSeg = "";
  if (lastPrompt > 0) {
    const idleSeconds = Math.max(0, nowEpoch - lastPrompt);
    const idleColor = idleSeconds >= 3600 ? ORANGE : idleSeconds >= 900 ? PURPLE : BLUE;
    idleSeg = `${idleColor}idle ${fmtDuration(idleSeconds)}${RESET}`;
  }

  const usage = data?.context_window?.session_usage;
  let cacheSeg = "";
  if (usage && typeof usage === "object") {
    const read = asInt(usage.cache_read_input_tokens) ?? 0;
    const created = asInt(usage.cache_creation_input_tokens) ?? 0;
    const fresh = asInt(usage.input_tokens) ?? 0;
    const total = read + created + fresh;
    if (total > 0) {
      const hit = Math.round((read * 100) / total);
      const cacheColor = hit >= 50 ? GREEN : hit >= 20 ? YELLOW : `${BOLD}${RED}`;
      cacheSeg = `${cacheColor}cache ${hit}%${RESET}`;
    }
  }

  const added = asInt(gitSnapshot.added) ?? 0;
  const removed = asInt(gitSnapshot.removed) ?? 0;
  const diffSeg =
    added > 0 || removed > 0
      ? `${GREEN}+${added}${RESET}${FAINT}/${RESET}${RED}-${removed}${RESET}`
      : "";

  const wallMs = asInt(data?.cost?.total_duration_ms);
  const apiMs = asInt(data?.cost?.total_api_duration_ms);
  let timeSeg = "";
  if (wallMs != null && wallMs > 0) {
    timeSeg = `${BLUE}${fmtDuration(Math.floor(wallMs / 1000))}${RESET}`;
    if (apiMs != null && apiMs > wallMs) {
      const ratio = apiMs / wallMs;
      if (ratio >= 1.3) {
        const ratioColor = ratio >= 2.5 ? ORANGE : YELLOW;
        timeSeg += ` ${FAINT}·${RESET} ${ratioColor}api×${ratio.toFixed(1)}${RESET}`;
      }
    }
  }

  const usd = Number(data?.cost?.total_cost_usd);
  const costSeg = Number.isFinite(usd) ? `${TEXT}$${usd < 0.01 ? usd.toFixed(3) : usd < 10 ? usd.toFixed(2) : Math.round(usd).toString()}${RESET}` : "";

  const segments = [repoSeg, gitSeg, modelSeg, ctxSeg, idleSeg, cacheSeg, diffSeg, timeSeg, costSeg].filter(Boolean);
  while (segments.length > 3) {
    const painted = segments.join(SEP);
    if (visibleLength(painted) <= cols) break;
    segments.pop();
  }

  process.stdout.write(`${segments.join(SEP)}\n`);
}
