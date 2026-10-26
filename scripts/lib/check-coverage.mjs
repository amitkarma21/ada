#!/usr/bin/env node
// Reads `sf apex run test --code-coverage --json` output and enforces coverage thresholds
// for package classes (ADA_*, excluding ADA_Demo*). Usage:
//   node scripts/lib/check-coverage.mjs <apex-tests.json> <minOverall%> <minPerClass%>
// If the CLI's JSON shape changes, this exits with a clear "parser out of date" message:
// fix the parser, don't loosen the thresholds.
import { readFileSync } from 'node:fs';

const [file, minOverallArg = '85', minClassArg = '75'] = process.argv.slice(2);
const minOverall = Number(minOverallArg);
const minClass = Number(minClassArg);

function die(msg) {
  console.error(msg);
  process.exit(1);
}

let raw;
try {
  raw = JSON.parse(readFileSync(file, 'utf8'));
} catch (e) {
  die(`Could not read ${file} as JSON (${e.message}). Check apex-tests.stderr in the same folder.`);
}

const result = raw.result ?? raw;
const summary = result.summary;
if (!summary) {
  die(`Parser out of date: no "summary" in ${file}. Update scripts/lib/check-coverage.mjs.\n` +
      `Top-level keys: ${Object.keys(result).join(', ')}`);
}

const ran = Number(summary.testsRan ?? summary.testsran ?? 0);
const failing = Number(summary.failing ?? 0);
const outcome = String(summary.outcome ?? '');

const failures = (result.tests ?? []).filter((t) => String(t.Outcome ?? t.outcome).toLowerCase() === 'fail');
const lines = [];
lines.push(`Tests ran: ${ran}, failing: ${failing}, outcome: ${outcome}`);

if (failing > 0 || outcome.toLowerCase() === 'failed') {
  for (const t of failures.slice(0, 20)) {
    const name = t.FullName ?? `${t.ApexClass?.Name}.${t.MethodName}`;
    lines.push(`FAIL ${name}: ${t.Message ?? ''}`);
  }
  console.log(lines.join('\n'));
  die('Apex tests failed.');
}

const coverageList = result.coverage?.coverage ?? [];
const pkg = coverageList.filter((c) => /^ADA_/.test(c.name ?? '') && !/^ADA_Demo/.test(c.name ?? ''));

if (pkg.length === 0) {
  lines.push('No package classes yet — coverage check not applicable.');
  console.log(lines.join('\n'));
  process.exit(0);
}

const pctOf = (c) => Number(String(c.coveredPercent ?? c.percentage ?? '').replace('%', ''));

let totalLines = 0;
let totalCovered = 0;
let usedWeighted = true;
const lowClasses = [];
for (const c of pkg) {
  const pct = pctOf(c);
  if (String(c.coveredPercent ?? c.percentage ?? '') === '' || Number.isNaN(pct)) {
    die(`Parser out of date: no coveredPercent for ${c.name}. Update scripts/lib/check-coverage.mjs.`);
  }
  if (typeof c.totalLines === 'number' && typeof c.totalCovered === 'number') {
    totalLines += c.totalLines;
    totalCovered += c.totalCovered;
  } else {
    usedWeighted = false;
  }
  if (pct < minClass) lowClasses.push(`${c.name} ${pct}%`);
}

const overall = usedWeighted && totalLines > 0
  ? (100 * totalCovered) / totalLines
  : pkg.reduce((s, c) => s + pctOf(c), 0) / pkg.length;

const lowest = [...pkg].sort((a, b) => pctOf(a) - pctOf(b))[0];
lines.push(`Package coverage: ${overall.toFixed(1)}% across ${pkg.length} classes (min ${minOverall}%)`);
lines.push(`Lowest class: ${lowest.name} ${pctOf(lowest)}% (min ${minClass}%)`);
console.log(lines.join('\n'));

if (overall < minOverall) die(`Package coverage ${overall.toFixed(1)}% is below ${minOverall}%.`);
if (lowClasses.length) die(`Classes below ${minClass}%: ${lowClasses.join(', ')}`);
