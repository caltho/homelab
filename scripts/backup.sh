#!/usr/bin/env bash
#
# Backup the homelab stack (compose files, .env, and all container data under
# data/) into a timestamped, compressed tarball.
#
# HA's config files are root-owned, so we run tar inside a throwaway root
# container that bind-mounts the repo — no host sudo required. The current user
# just needs to be in the 'docker' group.
#
# Destination is configurable via DOCKER_BACKUP_DEST (default: ~/backups).
# To back up to the mounted Samsung T5 instead:
#   DOCKER_BACKUP_DEST=/mnt/t5/backups /home/callum/docker/scripts/backup.sh
#
set -euo pipefail

SRC=/home/callum/docker
DEST="${DOCKER_BACKUP_DEST:-/home/callum/backups}"
KEEP="${DOCKER_BACKUP_KEEP:-7}"        # how many recent backups to retain
# Image used only to run tar as root. Defaults to caddy:2 (already part of the
# stack, so no extra pull); override with any image that has tar.
IMAGE="${DOCKER_BACKUP_IMAGE:-caddy:2}"
DOCKER=/usr/bin/docker
TS=$(date +%Y%m%d-%H%M%S)
OUT="docker-backup-${TS}.tar.gz"

if [ ! -d "$DEST" ]; then
	echo "ERROR: backup destination '$DEST' does not exist (is the drive mounted?)" >&2
	exit 1
fi

echo "[$(date -Is)] Backing up $SRC -> $DEST/$OUT"

# Run tar as root inside a container so it can read root-owned HA config.
# Exclude transient/regenerable files (logs, sqlite WAL/SHM, exported CA).
"$DOCKER" run --rm \
	-v "$SRC":/src:ro \
	-v "$DEST":/backup \
	"$IMAGE" sh -c "tar czf /backup/'$OUT' -C /src \
		--exclude='./scripts/backup.log' \
		--exclude='./caddy-root-ca.crt' \
		--exclude='./data/homeassistant/config/*.log' \
		--exclude='./data/homeassistant/config/*.log.*' \
		--exclude='./data/homeassistant/config/home-assistant_v2.db-shm' \
		--exclude='./data/homeassistant/config/home-assistant_v2.db-wal' \
		--exclude='./data/homeassistant/config/.cache' \
		. "

# Retention: delete all but the newest $KEEP backups.
# shellcheck disable=SC2012
ls -1t "$DEST"/docker-backup-*.tar.gz 2>/dev/null | tail -n +"$((KEEP + 1))" | xargs -r rm -f

echo "[$(date -Is)] Done. Current backups:"
ls -lh "$DEST"/docker-backup-*.tar.gz
