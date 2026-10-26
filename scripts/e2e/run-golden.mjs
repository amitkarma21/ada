#!/usr/bin/env node
// Runs every case in test-data/golden-errors.json through ADA_DiagnosisService in the org and
// reports accuracy and confident-wrong answers.
//
// Apex contract (built in step 1.4):
//   public static Map<String, Object> ADA_DiagnosisService.diagnoseForHarness(String objectApiName, String message)
//   returns keys: type (String), componentApiName (String|null), confidence (Decimal 0-1), threshold (Decimal)
//
// Usage: node scripts/e2e/run-golden.mjs --org ada-dev [--min-accuracy 0.95] [--out report.md]
// Env: ADA_NS="ns." when testing a namespaced org.
import { readFileSync, writeFileSync } from 'node:fs';
import { runApex, extractMarkers, apexString } from '../lib/run-apex-markers.mjs';

const args = process.argv.slice(2);
const get = (n, d) => {
  const i = args.indexOf(`--${n}`);
  return i >= 0 ? args[i + 1] : d;
};
const org = get('org');
const minAccuracy = Number(get('min-accuracy', '0.95'));
const outFile = get('out');
const ns = process.env.ADA_NS ?? '';
if (!org) {
  console.error('Usage: run-golden.mjs --org <alias> [--min-accuracy 0.95] [--out report.md]');
  process.exit(2);
}

const golden = JSON.parse(readFileSync('test-data/golden-errors.json', 'utf8'));
const cases = golden.cases.filter((c) => c.message && c.message.trim());
const missing = golden.cases.length - cases.length;
if (cases.length === 0 || missing > 0) {
  const ids = golden.cases.filter((c) => !c.message || !c.message.trim()).map((c) => c.id);
  console.error(`Golden cases without a message: ${ids.join(', ')}. ` +
    'Fill them (step 0.3: scripts/e2e/capture-golden.mjs, or by hand for manual cases) before running the golden set.');
  process.exit(1);
}

const BATCH = 15;
const results = new Map();
for (let i = 0; i < cases.length; i += BATCH) {
  const batch = cases.slice(i, i + BATCH);
  const code = batch
    .map((c) => {
      const id = apexString(c.id);
      return `try { System.debug(LoggingLevel.ERROR, 'ADA_RESULT|' + JSON.serialize(new Map<String, Object>{ 'id' => ${id}, 'r' => ${ns}ADA_DiagnosisService.diagnoseForHarness(${apexString(c.object)}, ${apexString(c.message)}) })); } catch (Exception e) { System.debug(LoggingLevel.ERROR, 'ADA_RESULT|' + JSON.serialize(new Map<String, Object>{ 'id' => ${id}, 'error' => e.getMessage() })); }`;
    })
    .join('\n');
  const r = runApex({ org, code });
  if (!r.compiled) {
    console.error(`Harness compile error: ${r.compileProblem}`);
    process.exit(1);
  }
  for (const line of extractMarkers(r.logs, 'ADA_RESULT')) {
    try {
      const obj = JSON.parse(line);
      results.set(obj.id, obj);
    } catch {
      console.error(`Unparseable result line: ${line.slice(0, 200)}`);
    }
  }
}

let correct = 0;
let confidentWrong = 0;
const rows = [];
for (const c of cases) {
  const res = results.get(c.id);
  const exp = c.expected ?? {};
  let verdict;
  let got = '—';
  if (!res) {
    verdict = 'NO RESULT';
  } else if (res.error) {
    verdict = 'ERROR';
    got = res.error;
  } else {
    const r = res.r ?? {};
    const confident = Number(r.confidence) >= Number(r.threshold ?? 0.8);
    got = `${r.type} ${r.componentApiName ?? ''} (${Number(r.confidence).toFixed(2)})`.trim();
    const typeOk = r.type === exp.type || (exp.type === 'UNKNOWN' && !confident);
    const compOk = !exp.componentApiName || r.componentApiName === exp.componentApiName;
    if (typeOk && compOk) {
      verdict = 'OK';
      correct++;
    } else if (confident) {
      verdict = 'CONFIDENT WRONG';
      confidentWrong++;
    } else {
      verdict = 'WRONG (low confidence)';
    }
  }
  rows.push(`| ${c.id} | ${exp.type ?? ''} ${exp.componentApiName ?? ''} | ${got} | ${verdict} |`);
}

const accuracy = correct / cases.length;
const report = [
  `Golden set: ${correct}/${cases.length} correct, accuracy ${(accuracy * 100).toFixed(1)}% (min ${(minAccuracy * 100).toFixed(0)}%), confident wrong: ${confidentWrong} (max 0)` +
    (missing ? `, ${missing} case(s) skipped with no message` : ''),
  '',
  '| Case | Expected | Got | Verdict |',
  '| --- | --- | --- | --- |',
  ...rows
].join('\n');
console.log(report);
if (outFile) writeFileSync(outFile, report + '\n', 'utf8');

if (confidentWrong > 0 || accuracy < minAccuracy) process.exit(1);
