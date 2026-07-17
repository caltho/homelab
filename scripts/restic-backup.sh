#!/usr/bin/env bash
#
# Encrypted restic backup of the homelab stack to the Samsung T5 SSD.
#
# What it backs up: all of ~/docker EXCEPT data/media — i.e. the HA config,
# the compose "recipe" (compose.yaml, .env, Caddyfile, scripts, docs) and all
# container state (which lives as bind mounts under data/: homeassistant,
# plex/config, portainer, caddy, samba). The 705 GB Plex media library under
# data/media is deliberately excluded (too large + re-obtainable).
#
# HA's config files are root-owned, so — like scripts/backup.sh — we run restic
# inside the official restic/restic container as root. No host sudo needed; the
# invoking user just needs docker-group access (cron gets it automatically).
#
# Repo:     data/media/restic-repo on the T5  (only path physically on the T5)
# Password: ~/.config/restic/password  (chmod 600; KEEP A COPY OFF-MACHINE!)
# Schedule: nightly via the user crontab. Retention: 7 daily / 4 weekly / 6 monthly.
set -euo pipefail

SRC=/home/callum/docker
MEDIA_MNT=/home/callum/docker/data/media
REPO_HOST="$MEDIA_MNT/backups/restic-repo"
PWFILE=/home/callum/.config/restic/password
IMAGE="${RESTIC_IMAGE:-restic/restic:latest}"
DOCKER=/usr/bin/docker

# Safety checks: never write the repo to the NVMe if the T5 is unmounted, and
# never run without the encryption key.
if ! mountpoint -q "$MEDIA_MNT"; then
	echo "ERROR: Samsung T5 not mounted at $MEDIA_MNT — aborting (won't back up to NVMe)." >&2
	exit 1
fi
if [ ! -f "$PWFILE" ]; then
	echo "ERROR: restic password file $PWFILE missing — aborting." >&2
	exit 1
fi
mkdir -p "$MEDIA_MNT/backups"

echo "[$(date -Is)] restic backup start ($SRC + claude-telegram-bridge -> $REPO_HOST)"

"$DOCKER" run --rm \
	--hostname bongripper \
	-e RESTIC_REPOSITORY=/backups/restic-repo \
	-e RESTIC_PASSWORD_FILE=/pw \
	-v "$SRC":/src:ro \
	-v /home/callum/claude-telegram-bridge:/bridge:ro \
	-v "$MEDIA_MNT/backups":/backups \
	-v "$PWFILE":/pw:ro \
	--entrypoint /bin/sh \
	"$IMAGE" -c '
		set -e
		# Initialise the repo on first run (idempotent).
		restic cat config >/dev/null 2>&1 || restic init
		restic backup /src /bridge \
			--tag nightly \
			--exclude-caches \
			--exclude=/bridge/node_modules \
			--exclude=/src/data/media \
			--exclude=/src/caddy-root-ca.crt \
			--exclude=/src/scripts/backup.log \
			--exclude=/src/scripts/restic-backup.log \
			--exclude=/src/scripts/git-backup.log \
			--exclude="/src/data/homeassistant/config/*.log" \
			--exclude="/src/data/homeassistant/config/*.log.*" \
			--exclude=/src/data/homeassistant/config/home-assistant_v2.db-shm \
			--exclude=/src/data/homeassistant/config/home-assistant_v2.db-wal \
			--exclude=/src/data/homeassistant/config/.cache
		echo "--- retention: keep 7 daily / 4 weekly / 6 monthly, prune older ---"
		restic forget --tag nightly \
			--keep-daily 7 --keep-weekly 4 --keep-monthly 6 \
			--prune
	'

echo "[$(date -Is)] restic backup done"
