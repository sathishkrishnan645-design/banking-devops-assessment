#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# health-check.sh — Verify banking-app is healthy
# Usage: ./scripts/health-check.sh [HOST] [PORT]
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-8090}"
API_KEY="${API_KEY:-banking-secret-key-2024}"
BASE_URL="http://${HOST}:${PORT}"

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}  ✅ PASS${NC} — $1"; }
fail() { echo -e "${RED}  ❌ FAIL${NC} — $1"; FAILED=$((FAILED+1)); }
log()  { echo -e "${BLUE}▶${NC} $1"; }

FAILED=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Banking App Health Check"
echo "  Target: ${BASE_URL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Test 1: Health endpoint ───────────────────────────────────────────────────
log "Testing /health endpoint..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health")
[ "${RESPONSE}" = "200" ] && pass "/health returns 200" || fail "/health returned ${RESPONSE}"

# ── Test 2: Auth required ─────────────────────────────────────────────────────
log "Testing authentication required..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/accounts/TEST/balance")
[ "${RESPONSE}" = "401" ] && pass "Returns 401 without API key" || fail "Expected 401, got ${RESPONSE}"

# ── Test 3: API key works ─────────────────────────────────────────────────────
log "Testing API key authentication..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-API-Key: ${API_KEY}" \
    "${BASE_URL}/accounts/NONEXISTENT/balance")
[ "${RESPONSE}" = "404" ] && pass "API key accepted (404 for missing account)" || fail "Expected 404, got ${RESPONSE}"

# ── Test 4: Create account ────────────────────────────────────────────────────
log "Testing account creation..."
TEST_ACC="HEALTH-CHECK-$(date +%s)"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${BASE_URL}/accounts" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"account_number\":\"${TEST_ACC}\",\"owner_name\":\"Test User\",\"initial_balance\":100}")
[ "${RESPONSE}" = "201" ] && pass "Account created successfully" || fail "Expected 201, got ${RESPONSE}"

# ── Test 5: Deposit ───────────────────────────────────────────────────────────
log "Testing deposit..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${BASE_URL}/accounts/${TEST_ACC}/deposit" \
    -H "X-API-Key: ${API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"amount": 50}')
[ "${RESPONSE}" = "200" ] && pass "Deposit successful" || fail "Expected 200, got ${RESPONSE}"

# ── Test 6: Balance ───────────────────────────────────────────────────────────
log "Testing balance check..."
BALANCE=$(curl -s \
    -H "X-API-Key: ${API_KEY}" \
    "${BASE_URL}/accounts/${TEST_ACC}/balance" | python3 -c "import sys,json; print(json.load(sys.stdin)['balance'])" 2>/dev/null || echo "0")
[ "${BALANCE}" = "150.0" ] && pass "Balance correct: ${BALANCE}" || fail "Expected 150.0, got ${BALANCE}"

# ── Test 7: Cleanup ───────────────────────────────────────────────────────────
log "Cleaning up test account..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X DELETE "${BASE_URL}/accounts/${TEST_ACC}" \
    -H "X-API-Key: ${API_KEY}")
[ "${RESPONSE}" = "200" ] && pass "Test account deleted" || fail "Expected 200, got ${RESPONSE}"

# ── Docker status ─────────────────────────────────────────────────────────────
log "Checking Docker container status..."
if docker ps --filter "name=banking-app" --filter "status=running" | grep -q banking-app; then
    pass "Docker container is running"
else
    fail "Docker container is not running"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "${FAILED}" = "0" ]; then
    echo -e "${GREEN}  All checks passed! ✅${NC}"
    exit 0
else
    echo -e "${RED}  ${FAILED} check(s) failed! ❌${NC}"
    exit 1
fi
