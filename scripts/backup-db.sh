#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
# backup-db.sh — Backup PostgreSQL banking database to S3
# Usage: ./scripts/backup-db.sh
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
DB_HOST="${DB_HOST:-172.31.8.218}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-bankdb}"
DB_USER="${DB_USER:-bankuser}"
PGPASSWORD="${DB_PASSWORD:-bankpassword123}"
S3_BUCKET="${S3_BUCKET:-banking-app-backups}"
BACKUP_DIR="/tmp/db-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/bankdb_${TIMESTAMP}.sql.gz"
RETAIN_DAYS=7

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log()     { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"; exit 1; }

export PGPASSWORD

# ── Pre-flight ────────────────────────────────────────────────────────────────
command -v pg_dump &>/dev/null || error "pg_dump not found — install postgresql-client"
command -v aws &>/dev/null || error "aws cli not found"

mkdir -p "${BACKUP_DIR}"

# ── Backup ────────────────────────────────────────────────────────────────────
log "Starting backup of ${DB_NAME} from ${DB_HOST}:${DB_PORT}..."

pg_dump \
    -h "${DB_HOST}" \
    -p "${DB_PORT}" \
    -U "${DB_USER}" \
    -d "${DB_NAME}" \
    --verbose \
    --format=plain \
    --no-password \
    | gzip > "${BACKUP_FILE}"

BACKUP_SIZE=$(du -sh "${BACKUP_FILE}" | cut -f1)
success "Backup created: ${BACKUP_FILE} (${BACKUP_SIZE})"

# ── Upload to S3 ──────────────────────────────────────────────────────────────
log "Uploading to s3://${S3_BUCKET}/backups/$(basename ${BACKUP_FILE})..."

aws s3 cp "${BACKUP_FILE}" \
    "s3://${S3_BUCKET}/backups/$(basename ${BACKUP_FILE})" \
    --region ap-southeast-2 \
    --storage-class STANDARD_IA

success "Uploaded to S3"

# ── Cleanup local ─────────────────────────────────────────────────────────────
rm -f "${BACKUP_FILE}"
log "Local backup file removed"

# ── Remove old S3 backups ─────────────────────────────────────────────────────
log "Removing S3 backups older than ${RETAIN_DAYS} days..."
CUTOFF_DATE=$(date -d "${RETAIN_DAYS} days ago" +%Y-%m-%d)

aws s3 ls "s3://${S3_BUCKET}/backups/" \
    | awk '{print $4}' \
    | while read -r file; do
        FILE_DATE=$(echo "${file}" | grep -oP '\d{8}' | head -1)
        if [[ "${FILE_DATE}" < "${CUTOFF_DATE//\-/}" ]]; then
            log "Deleting old backup: ${file}"
            aws s3 rm "s3://${S3_BUCKET}/backups/${file}" --region ap-southeast-2
        fi
    done

success "Backup complete — ${DB_NAME} → s3://${S3_BUCKET}/backups/"
