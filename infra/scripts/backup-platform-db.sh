#!/bin/bash
# Backs up the PLATFORM database (users/workspaces/events/snapshots metadata)
# — distinct from workspace snapshots, which back up individual workspace
# volumes. Stored in its own volume, separate from mongo's own data volume,
# per the spec's "backups must be separate from the primary disk" guidance.
set -euo pipefail

NETWORK="${PLATFORM_NETWORK:-cloudworkspace-platform}"
MONGO_HOST="${MONGO_SERVICE_HOST:-mongo}"
BACKUP_VOLUME="${BACKUP_VOLUME:-cloudworkspace-platform-backups}"
RETENTION_COUNT="${RETENTION_COUNT:-14}"

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
ARCHIVE_NAME="platform-db-${TIMESTAMP}.archive.gz"

docker volume create "$BACKUP_VOLUME" > /dev/null

# The mongo image's entrypoint auto-drops any `mongo*` command (mongodump
# included) to the "mongodb" user (uid 999) — a freshly created volume
# defaults to root ownership, so it can't write there without this.
docker run --rm -v "$BACKUP_VOLUME:/backups" alpine chown -R 999:999 /backups

docker run --rm \
  --network "$NETWORK" \
  -v "$BACKUP_VOLUME:/backups" \
  mongo:7 \
  mongodump --host "$MONGO_HOST" --gzip --archive="/backups/${ARCHIVE_NAME}"

echo "Backup created: ${ARCHIVE_NAME}"

docker run --rm -v "$BACKUP_VOLUME:/backups" alpine sh -c "
  cd /backups && ls -1t platform-db-*.archive.gz 2>/dev/null | tail -n +\$(( ${RETENTION_COUNT} + 1 )) | xargs -r rm -v
"
