#!/usr/bin/env bash
# Invariant checks that need no org. Called by `verify.sh static`. Exits non-zero on any violation.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

fail=0
report() { echo "VIOLATION: $1"; fail=1; }

PKG="force-app"
[[ -d "$PKG" ]] || { echo "No ${PKG}/ yet — nothing to check."; exit 0; }

# 1. No session-ID callouts (security review blocker).
if grep -rn "getSessionId" "$PKG" --include="*.cls" --include="*.trigger" >/dev/null 2>&1; then
  report "UserInfo.getSessionId() used in package code:"
  grep -rn "getSessionId" "$PKG" --include="*.cls" --include="*.trigger"
fi

# 2. Only ADA_HttpGateway may create or send HTTP requests.
offenders="$(grep -rlE "new Http\(\)|\.send\(" "$PKG" --include="*.cls" 2>/dev/null \
  | grep -v "/ADA_HttpGateway.cls$" || true)"
if [[ -n "$offenders" ]]; then
  report "HTTP sent outside ADA_HttpGateway:"
  echo "$offenders"
fi

# 3. No hardcoded URLs in Apex (use Named Credentials). Allow with a trailing // ada-allow-url comment.
urls="$(grep -rnE "https?://" "$PKG" --include="*.cls" 2>/dev/null | grep -v "ada-allow-url" || true)"
if [[ -n "$urls" ]]; then
  report "Hardcoded URL in Apex (use callout:ADA_...):"
  echo "$urls"
fi

# 4. Demo metadata must not be in the package.
demo="$(grep -rl "ADA_Demo" "$PKG" 2>/dev/null || true)"
if [[ -n "$demo" ]]; then
  report "Demo components referenced inside the package:"
  echo "$demo"
fi

# 5. Canary values must never appear in package source, except in test classes (*Test.cls),
#    which need them to seed records for the egress canary test.
if [[ -f test-data/canaries.json ]]; then
  while IFS= read -r value; do
    [[ -z "$value" ]] && continue
    hits="$(grep -rnF -- "$value" "$PKG" 2>/dev/null | grep -vE "Test\.cls:" || true)"
    if [[ -n "$hits" ]]; then
      report "Canary value '${value}' found in non-test package source:"
      echo "$hits"
    fi
  done < <(node -e "for (const v of require('./test-data/canaries.json').values) console.log(v)")
fi

# 6. Data files must be valid JSON.
for f in test-data/*.json; do
  [[ -e "$f" ]] || continue
  node -e "JSON.parse(require('fs').readFileSync('$f','utf8'))" 2>/dev/null || report "Invalid JSON: $f"
done

# 7. No SeeAllData=true in tests.
if grep -rniE "SeeAllData *= *true" "$PKG" --include="*.cls" >/dev/null 2>&1; then
  report "SeeAllData=true in a test class."
fi

# 8. Reports, report types and dashboards must not read the payload, result or link columns of the log.
leaks="$(grep -rnE "Payload_Sent__c|Result__c|External_Id__c|External_Url__c|Session_Key__c|Idempotency_Key__c" "$PKG/main/default/reports" "$PKG/main/default/reportTypes" "$PKG/main/default/dashboards" 2>/dev/null || true)"
if [[ -n "$leaks" ]]; then
  report "A report, report type or dashboard reads a log column that can hold request data:"
  echo "$leaks"
fi

[[ "$fail" == 0 ]] && echo "All invariant checks passed."
exit "$fail"
