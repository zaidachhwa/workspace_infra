#!/bin/bash
# Restores the platform database from a backup made by backup-platform-db.sh.
# DESTRUCTIVE: --drop replaces every existing collection with the backup's
# contents. Requires typing "yes" to confirm — no --force flag, on purpose.
set -euo pipefail

NETWORK="${PLATFORM_NETWORK:-cloudworkspace-platform}"
MONGO_HOST="${MONGO_SERVICE_HOST:-mongo}"
BACKUP_VOLUME="${BACKUP_VOLUME:-cloudworkspace-platform-backups}"

ARCHIVE_NAME="${1:?Usage: restore-platform-db.sh <archive-filename> (see list-platform-backups.sh)}"

echo "This will REPLACE the current platform database with the contents of ${ARCHIVE_NAME}."
read -rp "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 1
fi

docker run --rm \
  --network "$NETWORK" \
  -v "$BACKUP_VOLUME:/backups" \
  mongo:7 \
  mongorestore --host "$MONGO_HOST" --gzip --archive="/backups/${ARCHIVE_NAME}" --drop

echo "Restore complete."
