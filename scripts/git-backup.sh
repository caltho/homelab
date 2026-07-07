#!/usr/bin/env bash
#
# Nightly off-machine backup of the homelab "recipe": commit any changes under
# ~/docker and push to GitHub (git@github.com:caltho/homelab.git).
#
# data/ and .env are gitignored, so only non-secret source is pushed — this is
# the off-machine complement to the local restic data backup on the T5.
#
# Runs non-interactively from cron: uses the ed25519 deploy key directly and
# disables any credential prompts.
set -euo pipefail

cd /home/callum/docker

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -i /home/callum/.ssh/id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

if [ -n "$(git status --porcelain)" ]; then
	git add -A
	git commit -m "nightly snapshot $(date +%Y-%m-%d)"
	echo "[$(date -Is)] committed local changes"
else
	echo "[$(date -Is)] no local changes to commit"
fi

# Push HEAD (also flushes any earlier unpushed commits).
git push origin HEAD
echo "[$(date -Is)] pushed to origin"
