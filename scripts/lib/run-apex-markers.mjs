#!/usr/bin/env node
// Runs anonymous Apex in an org and checks marker lines in the debug log.
// Apex prints markers with: System.debug(LoggingLevel.ERROR, 'ADA_INDEX_OK|' + detail);
//
// CLI:  node scripts/lib/run-apex-markers.mjs --org ada-dev --file x.apex --expect ADA_X_OK [--fail-on ADA_X_FAIL]
// Lib:  import { runApex, extractMarkers } from './run-apex-markers.mjs'
import { spawnSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

export function runApex({ org, file, code }) {
  let path = file;
  if (!path) {
    const dir = mkdtempSync(join(tmpdir(), 'ada-apex-'));
    path = join(dir, 'snippet.apex');
    writeFileSync(path, code, 'utf8');
  }
  const res = spawnSync('sf', ['apex', 'run', '--file', path, '--target-org', org, '--json'], {
    encoding: 'utf8',
    maxBuffer: 64 * 1024 * 1024
  });
  const stdout = res.stdout ?? '';
  let parsed = null;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    /* fall back to raw text */
  }
  const result = parsed?.result ?? {};
  const logs = typeof result.logs === 'string' ? result.logs : stdout;
  return {
    ok: res.status === 0 && result.success !== false,
    compiled: result.compiled !== false,
    compileProblem: result.compileProblem,
    exceptionMessage: result.exceptionMessage,
    exceptionStackTrace: result.exceptionStackTrace,
    logs,
    stderr: res.stderr ?? ''
  };
}

// Returns the text after "<MARKER>|" for every log line that contains it.
// The platform HTML-escapes "|" and a few other characters inside debug-log message text, so
// decode them before matching or the marker delimiter never appears.
function decodeLogEntities(s) {
  return s
    .replace(/&#124;/g, '|')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, '&');
}

export function extractMarkers(logs, marker) {
  const out = [];
  const re = new RegExp(`${marker}\\|(.*)$`);
  for (const line of logs.split(/\r?\n/)) {
    // The CLI echoes the submitted source as "Execute Anonymous: ..." lines; ignore those.
    if (line.startsWith('Execute Anonymous:')) continue;
    const m = decodeLogEntities(line).match(re);
    if (m) out.push(m[1]);
  }
  return out;
}

// Escapes a JS string for use inside an Apex single-quoted string literal.
export function apexString(s) {
  return "'" + String(s)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\r/g, '\\r')
    .replace(/\n/g, '\\n')
    .replace(/\t/g, '\\t') + "'";
}

function cli() {
  const args = process.argv.slice(2);
  const get = (name) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const org = get('org');
  const file = get('file');
  const expect = get('expect');
  const failOn = get('fail-on');
  if (!org || !file || !expect) {
    console.error('Usage: run-apex-markers.mjs --org <alias> --file <apex> --expect <MARKER> [--fail-on <MARKER>]');
    process.exit(2);
  }
  readFileSync(file); // fail early if missing
  const r = runApex({ org, file });
  if (!r.compiled) {
    console.error(`Compile error: ${r.compileProblem}`);
    process.exit(1);
  }
  if (r.exceptionMessage) {
    console.error(`Exception: ${r.exceptionMessage}\n${r.exceptionStackTrace ?? ''}`);
    process.exit(1);
  }
  const fails = failOn ? extractMarkers(r.logs, failOn) : [];
  const oks = extractMarkers(r.logs, expect);
  for (const f of fails) console.error(`${failOn}: ${f}`);
  for (const o of oks) console.log(`${expect}: ${o}`);
  if (fails.length || oks.length === 0) {
    if (!oks.length) console.error(`No ${expect} marker found in the debug log.`);
    process.exit(1);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) cli();
