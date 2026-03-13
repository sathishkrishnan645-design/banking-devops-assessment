#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# deploy.sh — Deploy banking-app Docker container
# Usage: ./scripts/deploy.sh [VERSION]
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="banking-app"
NEXUS_REGISTRY="${NEXUS_REGISTRY:-3.106.152.10:8082}"
VERSION="${1:-latest}"
APP_PORT="${APP_PORT:-8090}"
DB_HOST="${DB_HOST:-172.31.8.218}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-bankdb}"
DB_USER="${DB_USER:-bankuser}"
DB_PASSWORD="${DB_PASSWORD:-bankpassword123}"
API_KEY="${API_KEY:-banking-secret-key-2024}"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
log "Starting deployment of ${APP_NAME}:${VERSION}"

command -v docker &>/dev/null || error "Docker not found"
docker info &>/dev/null || error "Docker daemon not running"

# ── Pull image ────────────────────────────────────────────────────────────────
log "Pulling image from Nexus: ${NEXUS_REGISTRY}/${APP_NAME}:${VERSION}"
docker pull "${NEXUS_REGISTRY}/${APP_NAME}:${VERSION}" || error "Failed to pull image"
success "Image pulled successfully"

# ── Stop existing container ───────────────────────────────────────────────────
if docker ps -q --filter "name=${APP_NAME}" | grep -q .; then
    log "Stopping existing container..."
    docker stop "${APP_NAME}" || warn "Failed to stop container"
fi

if docker ps -aq --filter "name=${APP_NAME}" | grep -q .; then
    log "Removing existing container..."
    docker rm "${APP_NAME}" || warn "Failed to remove container"
fi

# ── Start new container ───────────────────────────────────────────────────────
log "Starting new container ${APP_NAME}:${VERSION}..."
docker run -d \
    --name "${APP_NAME}" \
    --restart unless-stopped \
    -p "${APP_PORT}:${APP_PORT}" \
    -e DB_HOST="${DB_HOST}" \
    -e DB_PORT="${DB_PORT}" \
    -e DB_NAME="${DB_NAME}" \
    -e DB_USER="${DB_USER}" \
    -e DB_PASSWORD="${DB_PASSWORD}" \
    -e API_KEY="${API_KEY}" \
    "${NEXUS_REGISTRY}/${APP_NAME}:${VERSION}"

success "Container started"

# ── Health check ──────────────────────────────────────────────────────────────
log "Waiting for application to start..."
sleep 10

MAX_RETRIES=5
RETRY_INTERVAL=5

for i in $(seq 1 $MAX_RETRIES); do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 \
        "http://localhost:${APP_PORT}/health" 2>/dev/null || echo "000")

    log "Health check attempt ${i}/${MAX_RETRIES}: HTTP ${HTTP_CODE}"

    if [ "${HTTP_CODE}" = "200" ]; then
        success "Application is healthy at http://localhost:${APP_PORT}"
        docker ps --filter "name=${APP_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        exit 0
    fi

    sleep "${RETRY_INTERVAL}"
done

error "Health check failed after ${MAX_RETRIES} attempts"
