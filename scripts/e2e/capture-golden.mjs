#!/usr/bin/env node
// Step 0.3: runs scripts/e2e/capture-golden.apex in the demo org and stores the platform's exact
// error messages in test-data/golden-errors.json.
//
// The Apex prints one line per case:
//   System.debug(LoggingLevel.ERROR, 'ADA_GOLDEN|' + JSON.serialize(new Map<String, Object>{
//     'id' => 'opp-closedate-past', 'object' => 'Opportunity', 'statusCode' => '...', 'message' => '...' }));
//
// Cases already in the file keep their "expected" block; only "message" and "statusCode" update.
// Usage: node scripts/e2e/capture-golden.mjs --org ada-dev
import { readFileSync, writeFileSync } from 'node:fs';
import { runApex, extractMarkers } from '../lib/run-apex-markers.mjs';

const args = process.argv.slice(2);
const i = args.indexOf('--org');
const org = i >= 0 ? args[i + 1] : 'ada-dev';
const FILE = 'test-data/golden-errors.json';

const r = runApex({ org, file: 'scripts/e2e/capture-golden.apex' });
if (!r.compiled) {
  console.error(`Compile error: ${r.compileProblem}`);
  process.exit(1);
}
if (r.exceptionMessage) {
  console.error(`Exception: ${r.exceptionMessage}`);
  process.exit(1);
}

const captured = extractMarkers(r.logs, 'ADA_GOLDEN').map((l) => JSON.parse(l));
if (captured.length === 0) {
  console.error('No ADA_GOLDEN lines in the debug log.');
  process.exit(1);
}

const golden = JSON.parse(readFileSync(FILE, 'utf8'));
const byId = new Map(golden.cases.map((c) => [c.id, c]));
for (const cap of captured) {
  const existing = byId.get(cap.id);
  if (existing) {
    existing.message = cap.message;
    existing.statusCode = cap.statusCode;
    existing.source = 'captured';
  } else {
    golden.cases.push({
      id: cap.id,
      object: cap.object,
      message: cap.message,
      statusCode: cap.statusCode,
      source: 'captured',
      expected: { type: 'TODO', componentApiName: null }
    });
  }
}
golden.capturedAt = new Date().toISOString();
writeFileSync(FILE, JSON.stringify(golden, null, 2) + '\n', 'utf8');

const todo = golden.cases.filter((c) => c.expected?.type === 'TODO').map((c) => c.id);
const empty = golden.cases.filter((c) => !c.message).map((c) => c.id);
console.log(`Captured ${captured.length} case(s) into ${FILE}.`);
if (todo.length) console.log(`Set expected.type for: ${todo.join(', ')}`);
if (empty.length) console.log(`Still without a message (fill manually or capture): ${empty.join(', ')}`);
if (todo.length || empty.length) process.exit(1);
