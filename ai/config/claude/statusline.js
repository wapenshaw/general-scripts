#!/usr/bin/env node
'use strict';

/**
 * Claude Code - Personal Subscription Status Line
 * Windows / macOS / Linux, Node.js only, no npm dependencies.
 *
 * Displays:
 *   repo | git | model | context | idle | cache | 5h quota | 7d quota
 *   | exact code delta | duration/API ratio | PR
 *
 * Designed for a dark/gray terminal background.
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => { raw += chunk; });
process.stdin.on('end', main);

function main() {
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  // -------------------------------------------------------------------------
  // Palette
  // -------------------------------------------------------------------------

  const RESET = '\x1b[0m';
  const BOLD = '\x1b[1m';

  const TEXT = '\x1b[38;2;218;222;231m';
  const MUTED = '\x1b[38;2;145;151;166m';
  const FAINT = '\x1b[38;2;82;88;101m';

  const CYAN = '\x1b[38;2;78;201;240m';
  const BLUE = '\x1b[38;2;105;180;255m';
  const PURPLE = '\x1b[38;2;203;166;247m';

  const GREEN = '\x1b[38;2;93;214;136m';
  const YELLOW = '\x1b[38;2;244;205;108m';
  const ORANGE = '\x1b[38;2;247;148;83m';
  const RED = '\x1b[38;2;255;107;122m';

  const SEP = `${FAINT} │ ${RESET}`;

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  const asInt = (value, fallback = 0) => {
    const n = Number(value);
    return Number.isFinite(n) ? Math.trunc(n) : fallback;
  };

  const asNumber = (value, fallback = 0) => {
    const n = Number(value);
    return Number.isFinite(n) ? n : fallback;
  };

  const fmtCount = n => {
    n = asInt(n, 0);
    if (n >= 1_000_000) {
      const s = (n / 1_000_000).toFixed(1).replace(/\.0$/, '');
      return `${s}M`;
    }
    if (n >= 1_000) {
      const s = (n / 1_000).toFixed(1).replace(/\.0$/, '');
      return `${s}k`;
    }
    return String(n);
  };

  const fmtDuration = seconds => {
    seconds = Math.max(0, asInt(seconds, 0));

    if (seconds < 60) return `${seconds}s`;

    if (seconds < 3600) {
      const m = Math.floor(seconds / 60);
      const s = seconds % 60;
      return `${m}m${String(s).padStart(2, '0')}s`;
    }

    if (seconds < 86400) {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      return `${h}h${String(m).padStart(2, '0')}m`;
    }

    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    return `${d}d${String(h).padStart(2, '0')}h`;
  };

  const truncate = (value, max) => {
    const s = String(value ?? '');
    return s.length <= max ? s : `${s.slice(0, max - 1)}…`;
  };

  const usageColor = pct => {
    if (pct >= 90) return `${BOLD}${RED}`;
    if (pct >= 80) return ORANGE;
    if (pct >= 60) return YELLOW;
    return GREEN;
  };

  const runGit = (args, cwd) => {
    try {
      return execFileSync('git', ['-C', cwd, ...args], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
        windowsHide: true,
        timeout: 2500
      }).trimEnd();
    } catch {
      return '';
    }
  };

  // -------------------------------------------------------------------------
  // Runtime / state directory
  // -------------------------------------------------------------------------

  let cwd =
    data?.workspace?.current_dir ||
    data?.cwd ||
    process.cwd();

  if (!fs.existsSync(cwd)) cwd = process.cwd();

  const sessionId = String(data?.session_id || 'default');
  const safeSessionId = sessionId.replace(/[^A-Za-z0-9._-]/g, '_');
  const promptId = String(data?.prompt_id || '');

  const nowEpoch = Math.floor(Date.now() / 1000);
  const cols = asInt(process.env.COLUMNS, 160);

  const stateRoot = path.join(
    process.env.LOCALAPPDATA || os.tmpdir(),
    'ClaudeCode',
    'statusline'
  );

  try {
    fs.mkdirSync(stateRoot, { recursive: true });
  } catch {}

  // -------------------------------------------------------------------------
  // Repository
  // -------------------------------------------------------------------------

  let repo = data?.workspace?.repo?.name || '';

  if (!repo) {
    const gitRoot = runGit(['rev-parse', '--show-toplevel'], cwd);
    if (gitRoot) {
      repo = path.basename(gitRoot);
    } else {
      repo = path.basename(cwd);
    }
  }

  repo = truncate(repo, 28);
  const repoSeg = `${BOLD}${CYAN}◆ ${repo}${RESET}`;

  // -------------------------------------------------------------------------
  // Git status, cached for 10 seconds
  // -------------------------------------------------------------------------

  const gitCachePath = path.join(stateRoot, `git-${safeSessionId}.json`);

  let gitSnapshot = null;

  try {
    const stat = fs.statSync(gitCachePath);
    const ageSeconds = (Date.now() - stat.mtimeMs) / 1000;

    if (ageSeconds < 10) {
      gitSnapshot = JSON.parse(fs.readFileSync(gitCachePath, 'utf8'));
    }
  } catch {}

  if (!gitSnapshot) {
    const status = runGit(['status', '--porcelain=v1', '--branch'], cwd);

    let branch = 'no-git';
    let staged = 0;
    let modified = 0;
    let untracked = 0;
    let ahead = 0;
    let behind = 0;

    if (status) {
      for (const line of status.split(/\r?\n/)) {
        if (!line) continue;

        if (line.startsWith('## ')) {
          const header = line.slice(3);

          if (
            header.startsWith('HEAD (no branch)') ||
            header.startsWith('HEAD (detached')
          ) {
            const sha = runGit(['rev-parse', '--short', 'HEAD'], cwd);
            branch = sha ? `detached@${sha}` : 'detached';
          } else if (header.startsWith('No commits yet on ')) {
            branch = header.slice('No commits yet on '.length);
          } else if (header.startsWith('Initial commit on ')) {
            branch = header.slice('Initial commit on '.length);
          } else {
            branch = header.split('...')[0].split(' ')[0];
          }

          const aheadMatch = line.match(/ahead\s+(\d+)/);
          const behindMatch = line.match(/behind\s+(\d+)/);

          if (aheadMatch) ahead = Number(aheadMatch[1]);
          if (behindMatch) behind = Number(behindMatch[1]);

          continue;
        }

        if (line.startsWith('??')) {
          untracked++;
          continue;
        }

        if (line.length >= 2) {
          if (line[0] !== ' ') staged++;
          if (line[1] !== ' ') modified++;
        }
      }
    }

    gitSnapshot = { branch, staged, modified, untracked, ahead, behind };

    try {
      fs.writeFileSync(gitCachePath, JSON.stringify(gitSnapshot), 'utf8');
    } catch {}
  }

  gitSnapshot.branch = truncate(gitSnapshot.branch, 27);

  let gitSeg = `${PURPLE} ${gitSnapshot.branch}${RESET}`;
  if (gitSnapshot.staged > 0) {
    gitSeg += ` ${GREEN}+${gitSnapshot.staged}${RESET}`;
  }
  if (gitSnapshot.modified > 0) {
    gitSeg += ` ${YELLOW}~${gitSnapshot.modified}${RESET}`;
  }
  if (gitSnapshot.untracked > 0) {
    gitSeg += ` ${MUTED}?${gitSnapshot.untracked}${RESET}`;
  }
  if (gitSnapshot.ahead > 0) {
    gitSeg += ` ${GREEN}↑${gitSnapshot.ahead}${RESET}`;
  }
  if (gitSnapshot.behind > 0) {
    gitSeg += ` ${ORANGE}↓${gitSnapshot.behind}${RESET}`;
  }

  // -------------------------------------------------------------------------
  // Model / effort
  // -------------------------------------------------------------------------

  const modelId = String(data?.model?.id || '');
  let model = String(data?.model?.display_name || '?');

  if (modelId.startsWith('claude-opus-5-5')) model = 'Opus 5.5';
  if (modelId.startsWith('claude-sonnet-5')) model = 'Sonnet 5';
  if (modelId.startsWith('claude-haiku-4-5')) model = 'Haiku 4.5';

  const effort = String(data?.effort?.level || '');
  const effortShort = {
    low: 'L',
    medium: 'M',
    high: 'H',
    xhigh: 'X',
    max: 'MAX'
  }[effort] || '';

  let modelText = model;

  if (effortShort) modelText += `/${effortShort}`;
  if (data?.thinking?.enabled === true) modelText += '+T';
  if (data?.fast_mode === true) modelText += '+F';

  let modelSeg;
  if (effort === 'xhigh' || effort === 'max') {
    modelSeg = `${BOLD}${RED}${modelText}${RESET}`;
  } else if (effort === 'high') {
    modelSeg = `${BOLD}${PURPLE}${modelText}${RESET}`;
  } else {
    modelSeg = `${PURPLE}${modelText}${RESET}`;
  }

  // -------------------------------------------------------------------------
  // Context pressure against configured auto-compact window
  // -------------------------------------------------------------------------

  const ctxTokens = asInt(data?.context_window?.total_input_tokens, 0);
  const ctxSize = asInt(data?.context_window?.context_window_size, 0);

  let ctxLimit = asInt(process.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW, 0);
  if (ctxLimit <= 0) ctxLimit = ctxSize;
  if (ctxLimit <= 0) ctxLimit = 200000;
  if (ctxSize > 0 && ctxLimit > ctxSize) ctxLimit = ctxSize;

  const ctxPct =
    ctxLimit > 0
      ? Math.round((ctxTokens * 100) / ctxLimit)
      : 0;

  let ctxColor;
  if (ctxPct >= 90) ctxColor = `${BOLD}${RED}`;
  else if (ctxPct >= 80) ctxColor = ORANGE;
  else if (ctxPct >= 65) ctxColor = YELLOW;
  else ctxColor = GREEN;

  const ctxSeg =
    `${ctxColor}ctx ${fmtCount(ctxTokens)}${RESET}` +
    `${FAINT}/${RESET}` +
    `${ctxColor}${fmtCount(ctxLimit)} ${ctxPct}%${RESET}`;

  // -------------------------------------------------------------------------
  // Idle time from prompt_id
  // -------------------------------------------------------------------------

  const idleStatePath = path.join(
    stateRoot,
    `idle-${safeSessionId}.json`
  );

  let idleState = {
    prompt_id: '',
    last_prompt_epoch: 0
  };

  try {
    idleState = JSON.parse(fs.readFileSync(idleStatePath, 'utf8'));
  } catch {}

  if (promptId && promptId !== idleState.prompt_id) {
    idleState = {
      prompt_id: promptId,
      last_prompt_epoch: nowEpoch
    };

    try {
      fs.writeFileSync(
        idleStatePath,
        JSON.stringify(idleState),
        'utf8'
      );
    } catch {}
  }

  const lastPromptEpoch = asInt(idleState.last_prompt_epoch, 0);
  const idleSeconds =
    lastPromptEpoch > 0 && nowEpoch >= lastPromptEpoch
      ? nowEpoch - lastPromptEpoch
      : 0;

  let idleColor;
  if (idleSeconds >= 3600) idleColor = ORANGE;
  else if (idleSeconds >= 900) idleColor = PURPLE;
  else idleColor = BLUE;

  const idleSeg =
    `${idleColor}idle ${fmtDuration(idleSeconds)}${RESET}`;

  // -------------------------------------------------------------------------
  // Prompt cache
  //
  // Entire WARM segment = green
  // Entire COLD segment = red
  // -------------------------------------------------------------------------

  let cacheSeg = `${MUTED}cache --${RESET}`;
  const pc = data?.prompt_cache;

  if (pc?.caching_observed === true) {
    const cacheMisses = asInt(pc?.misses, 0);

    if (pc?.warm === true) {
      let text = 'cache WARM';

      const hit = asNumber(pc?.hit_ratio, -1);
      if (hit >= 0) {
        text += ` ${Math.round(hit * 100)}%`;
      }

      const expiresAt = asInt(pc?.expires_at, 0);
      if (expiresAt > nowEpoch) {
        text += ` · ${fmtDuration(expiresAt - nowEpoch)}`;
      }

      if (pc?.ttl) {
        text += `/${pc.ttl}`;
      }

      if (cacheMisses > 0) {
        text += ` m${cacheMisses}`;
      }

      cacheSeg = `${GREEN}${text}${RESET}`;
    } else {
      let text = 'cache COLD';

      const recache = asInt(pc?.recache_tokens_if_cold, 0);
      if (recache > 0) {
        text += ` ~${fmtCount(recache)}`;
      }

      if (cacheMisses > 0) {
        text += ` m${cacheMisses}`;
      }

      cacheSeg = `${BOLD}${RED}${text}${RESET}`;
    }
  }

  // -------------------------------------------------------------------------
  // Personal Claude subscription limits
  // -------------------------------------------------------------------------

  const rateSeg = (label, window) => {
    if (!window) return '';

    const pct = asNumber(window.used_percentage, -1);
    if (pct < 0) return '';

    let text = `${label} ${Math.round(pct)}%`;

    const resetsAt = asInt(window.resets_at, 0);
    if (resetsAt > nowEpoch) {
      text += ` ↻ ${fmtDuration(resetsAt - nowEpoch)}`;
    }

    return `${usageColor(pct)}${text}${RESET}`;
  };

  const fiveHourSeg = rateSeg(
    '5h',
    data?.rate_limits?.five_hour
  );

  const sevenDaySeg = rateSeg(
    '7d',
    data?.rate_limits?.seven_day
  );

  // -------------------------------------------------------------------------
  // Exact code delta -- deliberately not abbreviated
  // -------------------------------------------------------------------------

  const added = asInt(data?.cost?.total_lines_added, 0);
  const removed = asInt(data?.cost?.total_lines_removed, 0);

  const diffSeg =
    added > 0 || removed > 0
      ? `${GREEN}+${added}${RESET}` +
        `${FAINT}/${RESET}` +
        `${RED}-${removed}${RESET}`
      : '';

  // -------------------------------------------------------------------------
  // Session duration / parallel API pressure
  // -------------------------------------------------------------------------

  const wallMs = asInt(data?.cost?.total_duration_ms, 0);
  const apiMs = asInt(data?.cost?.total_api_duration_ms, 0);

  let timeSeg = '';

  if (wallMs > 0) {
    timeSeg =
      `${BLUE}${fmtDuration(Math.floor(wallMs / 1000))}${RESET}`;

    if (apiMs > wallMs) {
      const ratio = apiMs / wallMs;

      if (ratio >= 1.3) {
        const ratioColor = ratio >= 2.5 ? ORANGE : YELLOW;
        timeSeg +=
          ` ${FAINT}·${RESET} ` +
          `${ratioColor}api×${ratio.toFixed(1)}${RESET}`;
      }
    }
  }

  // -------------------------------------------------------------------------
  // PR
  // -------------------------------------------------------------------------

  let prSeg = '';
  const pr = data?.pr;

  if (pr?.number) {
    const label = `PR#${pr.number}`;

    switch (pr.review_state) {
      case 'approved':
        prSeg = `${GREEN}${label} ✓${RESET}`;
        break;
      case 'changes_requested':
        prSeg = `${RED}${label} !${RESET}`;
        break;
      case 'draft':
        prSeg = `${MUTED}${label} draft${RESET}`;
        break;
      default:
        prSeg = `${BLUE}${label}${RESET}`;
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Responsive render
  // -------------------------------------------------------------------------

  const segments = [
    repoSeg,
    gitSeg,
    modelSeg,
    ctxSeg,
    idleSeg,
    cacheSeg
  ];

  if (fiveHourSeg) segments.push(fiveHourSeg);
  if (sevenDaySeg) segments.push(sevenDaySeg);

  if (cols >= 140 && diffSeg) segments.push(diffSeg);
  if (cols >= 155 && timeSeg) segments.push(timeSeg);
  if (cols >= 175 && prSeg) segments.push(prSeg);

  process.stdout.write(`${segments.filter(Boolean).join(SEP)}\n`);
}
