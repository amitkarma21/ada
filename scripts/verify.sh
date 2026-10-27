#!/usr/bin/env bash
# ADA quality gates. Usage: scripts/verify.sh <doctor|static|unit|e2e|live|package>
# Each gate includes the ones before it (static < unit < e2e < live). Logs: .verify/<ts>-<gate>/
# Env: ADA_ORG (default ada-dev), ADA_DEVHUB (default ada-devhub), LIVE=1 for the live gate,
#      ADA_MIN_ORG_COVERAGE (85), ADA_MIN_CLASS_COVERAGE (75), ADA_MIN_GOLDEN_ACCURACY (0.95).
set -Eeuo pipefail

GATE="${1:-}"
ORG="${ADA_ORG:-ada-dev}"
DEVHUB="${ADA_DEVHUB:-ada-devhub}"
MIN_ORG_COV="${ADA_MIN_ORG_COVERAGE:-85}"
MIN_CLASS_COV="${ADA_MIN_CLASS_COVERAGE:-75}"
MIN_GOLDEN="${ADA_MIN_GOLDEN_ACCURACY:-0.95}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

case "$GATE" in
  doctor|static|unit|e2e|live|package) ;;
  *) echo "Usage: scripts/verify.sh <doctor|static|unit|e2e|live|package>"; exit 2 ;;
esac

TS="$(date +%Y%m%d-%H%M%S)"
LOG_DIR=".verify/${TS}-${GATE}"
mkdir -p "$LOG_DIR"
START="$(date +%s)"
RESULT="FAIL"
SKIPPED=()

finish() {
  local dur=$(( $(date +%s) - START ))
  local skipped="${SKIPPED[*]:-none}"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) gate=${GATE} result=${RESULT} duration=${dur}s org=${ORG} skipped=${skipped// /,} log=${LOG_DIR}" >> .verify/history.log
  echo
  echo "Gate '${GATE}': ${RESULT} in ${dur}s. Logs: ${LOG_DIR}"
  [[ "$RESULT" == "PASS" && "${#SKIPPED[@]}" -gt 0 ]] && echo "Skipped (not built yet): ${SKIPPED[*]}"
  return 0
}
trap finish EXIT

# run <name> <command...> — runs a check, logs output, stops the gate on failure.
run() {
  local name="$1"; shift
  echo "▶ ${name}"
  if "$@" >"${LOG_DIR}/${name}.log" 2>&1; then
    echo "  ✓ ${name}"
  else
    echo "  ✗ ${name} — last lines of ${LOG_DIR}/${name}.log:"
    tail -n 40 "${LOG_DIR}/${name}.log" | sed 's/^/    /'
    exit 1
  fi
}

skip() { echo "▷ $1 — skipped: $2"; SKIPPED+=("$1"); }

has_files() { [[ -d "$1" ]] && find "$1" -type f -name "$2" ! -name .gitkeep | grep -q .; }

require_org() {
  if ! sf org display --target-org "$ORG" >/dev/null 2>&1; then
    echo "Org '${ORG}' not found. Run scripts/new-scratch-org.sh first (or set ADA_ORG)."
    exit 1
  fi
}

gate_doctor() {
  run node node --version
  run npm npm --version
  run git git --version
  run sf-cli sf --version
  run code-analyzer-plugin bash -c "sf plugins | grep -i code-analyzer"
  run gh-auth gh auth status
  run devhub sf org display --target-org "$DEVHUB"
}

gate_static() {
  run npm-install-check test -d node_modules
  run prettier npx prettier --check --no-error-on-unmatched-pattern \
    "force-app/**/*.{cls,trigger,js,html,css,json,xml}" \
    "demo-app/**/*.{cls,trigger,js,html,css,json,xml}"
  run eslint npm run --silent lint
  run lwc-jest npm run --silent test:unit -- -- --passWithNoTests
  run invariant-checks bash scripts/lib/static-checks.sh
  if has_files force-app "*.cls" || has_files force-app "*.js"; then
    run code-analyzer sf code-analyzer run --workspace force-app --rule-selector Recommended \
      --severity-threshold 2 --output-file "${LOG_DIR}/code-analyzer.html"
  else
    skip code-analyzer "no package source yet"
  fi
}

gate_unit() {
  gate_static
  require_org
  local dirs=()
  has_files force-app "*" && dirs+=(--source-dir force-app)
  has_files demo-app "*" && dirs+=(--source-dir demo-app)
  if [[ "${#dirs[@]}" -gt 0 ]]; then
    run deploy sf project deploy start "${dirs[@]}" --target-org "$ORG" --wait 30
  else
    skip deploy "no source yet"
  fi
  echo "▶ apex-tests"
  sf apex run test --test-level RunLocalTests --code-coverage --wait 60 \
    --target-org "$ORG" --json >"${LOG_DIR}/apex-tests.json" 2>"${LOG_DIR}/apex-tests.stderr" || true
  run coverage node scripts/lib/check-coverage.mjs "${LOG_DIR}/apex-tests.json" "$MIN_ORG_COV" "$MIN_CLASS_COV"
  echo "  ✓ apex-tests"
  cat "${LOG_DIR}/coverage.log" | sed 's/^/    /'
}

gate_e2e() {
  gate_unit
  if [[ -f scripts/e2e/index-smoke.apex ]]; then
    run index-smoke node scripts/lib/run-apex-markers.mjs --org "$ORG" \
      --file scripts/e2e/index-smoke.apex --expect ADA_INDEX_OK --fail-on ADA_INDEX_FAIL
  else
    skip index-smoke "scripts/e2e/index-smoke.apex not written yet (step 1.3)"
  fi
  if [[ -f force-app/main/default/classes/ADA_DiagnosisService.cls ]]; then
    run golden-set node scripts/e2e/run-golden.mjs --org "$ORG" --min-accuracy "$MIN_GOLDEN" \
      --out "${LOG_DIR}/golden-report.md"
    sed 's/^/    /' "${LOG_DIR}/golden-report.md" | head -n 15
  else
    skip golden-set "ADA_DiagnosisService not built yet (step 1.4)"
  fi
}

gate_live() {
  if [[ "${LIVE:-0}" != "1" ]]; then
    echo "The live gate calls real external services. Re-run with LIVE=1 to confirm."
    exit 2
  fi
  gate_e2e
  local found=0
  for f in scripts/e2e/live-*.apex; do
    [[ -e "$f" ]] || continue
    found=1
    run "live-$(basename "$f" .apex)" node scripts/lib/run-apex-markers.mjs --org "$ORG" \
      --file "$f" --expect ADA_LIVE_OK --fail-on ADA_LIVE_FAIL
  done
  [[ "$found" == 1 ]] || skip live-tests "no scripts/e2e/live-*.apex yet"
}

gate_package() {
  gate_static
  if ! grep -q '"namespace": *"[A-Za-z]' sfdx-project.json; then
    echo "No namespace in sfdx-project.json yet (step 4.1)."; exit 1
  fi
  run package-version bash -c "sf package version create --package ADA --code-coverage \
    --installation-key-bypass --wait 60 --target-dev-hub '$DEVHUB' --json > '${LOG_DIR}/package-version.json'"
  local pkg_id
  pkg_id="$(node -e "const r=require('./${LOG_DIR}/package-version.json');console.log(r.result.SubscriberPackageVersionId||'')")"
  [[ -n "$pkg_id" ]] || { echo "No SubscriberPackageVersionId in package-version.json"; exit 1; }
  echo "  package version: ${pkg_id}"
  run install-org sf org create scratch --definition-file config/project-scratch-def.json \
    --alias ada-pkg --duration-days 1 --target-dev-hub "$DEVHUB" --wait 15
  run install sf package install --package "$pkg_id" --target-org ada-pkg --wait 30 --no-prompt
  run post-install-smoke node scripts/lib/run-apex-markers.mjs --org ada-pkg \
    --file scripts/e2e/post-install-smoke.apex --expect ADA_SMOKE_OK --fail-on ADA_SMOKE_FAIL
}

"gate_${GATE}"
RESULT="PASS"
