#!/usr/bin/env bash
#
# Home Assistant watchdog. HA can wedge with its process alive but its web server
# hung — a state `restart: unless-stopped` cannot catch because nothing exits.
# The compose healthcheck detects it (probes http://127.0.0.1:8123/); this script,
# run from cron, restarts HA when that healthcheck reports "unhealthy".
#
# Keys off the healthcheck STATUS (not a raw probe) so it never races HA's normal
# startup: during boot the status is "starting", and it only becomes "unhealthy"
# after ~3 consecutive failed checks (~3 min).
set -uo pipefail

DOCKER=/usr/bin/docker
CONTAINER=homeassistant
NOTIFY_VIA=claude-telegram-bridge   # bot container that has the `notify` command

status=$("$DOCKER" inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$CONTAINER" 2>/dev/null || echo "missing")

if [ "$status" = "unhealthy" ]; then
	echo "[$(date -Is)] HA healthcheck=unhealthy — restarting"
	"$DOCKER" restart "$CONTAINER"
	# Best-effort push to Callum's phone; never fail the watchdog on this.
	"$DOCKER" exec "$NOTIFY_VIA" notify \
		"🩺 HA watchdog: Home Assistant was unresponsive (hung), so I auto-restarted it." \
		>/dev/null 2>&1 || true
else
	# healthy / starting / none / missing -> nothing to do
	:
fi
