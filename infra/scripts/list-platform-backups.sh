#!/bin/bash
set -euo pipefail

BACKUP_VOLUME="${BACKUP_VOLUME:-cloudworkspace-platform-backups}"

docker run --rm -v "$BACKUP_VOLUME:/backups" alpine sh -c "ls -la /backups/ 2>/dev/null || echo 'No backups yet.'"
