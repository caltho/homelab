#!/usr/bin/env bash
#
# Nightly off-machine backup of the homelab "recipes": commit any changes in
# each stack repo (~/docker, ~/media-stack, ~/slskd, ~/claude-telegram-bridge)
# and push it to its GitHub remote.
#
# data/ and .env are gitignored, so only non-secret source is pushed — this is
# the off-machine complement to the local restic data backup on the T5.
#
# Runs non-interactively from cron: uses the ed25519 deploy key directly and
# disables any credential prompts.
set -euo pipefail

export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -i /home/callum/.ssh/id_ed25519 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# Each stack is its own repo; secrets (.env) and runtime state are gitignored in
# every one. A failure in one repo is logged but doesn't stop the others.
REPOS=(
	/home/callum/docker                  # caltho/homelab
	/home/callum/media-stack             # caltho/homelab-media-stack (private)
	/home/callum/slskd                   # caltho/homelab-slskd (private)
	/home/callum/claude-telegram-bridge  # caltho/claude-telegram-bridge (private)
)

rc=0
for repo in "${REPOS[@]}"; do
	if ! (
		cd "$repo"
		if [ -n "$(git status --porcelain)" ]; then
			git add -A
			git commit -m "nightly snapshot $(date +%Y-%m-%d)"
			echo "[$(date -Is)] $repo: committed local changes"
		else
			echo "[$(date -Is)] $repo: no local changes to commit"
		fi
		# Push HEAD (also flushes any earlier unpushed commits).
		git push origin HEAD
		echo "[$(date -Is)] $repo: pushed to origin"
	); then
		echo "[$(date -Is)] $repo: FAILED" >&2
		rc=1
	fi
done
exit $rc
