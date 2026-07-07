# Homelab — Docker stack (`~/docker`)

This repo runs a **personal, self-hosted home server** for Callum on the machine
`bongripper` (Ubuntu 24.04). It has nothing to do with work.

## ⚠️ Context guardrail — read first

This is a **private homelab**. Tasks here are about Home Assistant, Plex, Docker,
networking, smart bulbs, etc.

- **Do NOT use work/company tools for anything in this project.** No searching
  Microsoft 365 / Outlook / Teams chat, Atlassian (Jira/Confluence), SharePoint,
  or any `mcp__claude_ai_*` company connector. They are irrelevant here and
  surfacing them is a privacy problem.
  (Background: a previous agent asked to "set up Plex" went and searched Teams
  chat — don't do that.)
- Everything needed lives on this machine and the local network. Research goes
  to the web / official docs, not the user's employer systems.

## What's running

Compose stack defined in `compose.yaml` (project name `homelab`). Host LAN IP is
**`192.168.50.96`**.

| Service | Network | Access |
| --- | --- | --- |
| Home Assistant | host | `http://192.168.50.96:8123` · `https://ha.home.lan` |
| Plex (Intel Quick Sync) | host | `http://192.168.50.96:32400/web` · `https://plex.home.lan` |
| Samba | bridge :445 | `\\192.168.50.96\Media` (user `callum`) |
| Portainer | bridge :9443 | `https://192.168.50.96:9443` · `https://portainer.home.lan` |
| Caddy (reverse proxy) | bridge 80/443 | internal CA (self-signed) for `*.home.lan` |
| Cockpit *(host service, NOT compose)* | :9090 | `https://192.168.50.96:9090` · `https://cockpit.home.lan` |

## Layout & persistence

```
compose.yaml        # the stack
.env                # secrets + config (GITIGNORED — never commit)
.env.example        # template
caddy/Caddyfile     # reverse proxy vhosts
scripts/backup.sh   # backup script (see below)
data/               # ALL runtime state (GITIGNORED): HA config, Plex, etc.
```

- **Git tracks only the "recipe"** (compose, Caddyfile, scripts, docs). `data/`
  and `.env` are gitignored on purpose (large/binary/secret).
- **`data/` is a bind mount = the real state.** Survives reboots automatically
  (`restart: unless-stopped`). HA integrations (e.g. the 3 WiZ bulbs) live in
  `data/homeassistant/config/.storage/core.config_entries`.
- **The Samsung T5 SSD is mounted at `data/media`** (fstab, UUID `A463-7C51`,
  exFAT, uid/gid 1000). It holds the Plex media library (~923 GB, near full).
  This is a separate physical disk from the OS/config NVMe.
- To rebuild on new hardware: restore `data/` from a backup + `docker compose up -d`.

## Operational gotchas (important)

- **`sudo` requires a password and can't be run non-interactively** (no
  passwordless sudo). Anything needing root (apt installs, mounting disks,
  editing `/etc/...`) must be handed to Callum to run in a real terminal.
- **The `docker` group:** Callum was added to it via `usermod`, but a shell
  started before that (or lacking the group) must wrap docker commands as
  `sg docker -c '...'`. Fresh logins and cron jobs get the group normally.
- **HA config files are root-owned.** Edit them *through the container*
  (`docker exec homeassistant sh -c '...'`) rather than with host sudo.
- **Caddy uses an internal CA**, so browsers warn until Caddy's root cert
  (`caddy-root-ca.crt`, exported to repo root, gitignored) is trusted per device.
  `*.home.lan` names also need DNS/hosts entries pointing at `192.168.50.96`.
- Stack is **LAN-only by design** — nothing is exposed to the internet. Remote
  phone access would need a VPN (Tailscale/WireGuard) or Home Assistant Cloud.

## Backups

- `scripts/backup.sh` tars `~/docker` (config + `.env`) to a timestamped
  `.tar.gz`, keeping the last 7. Runs tar inside a container (image `caddy:2`) so
  it can read root-owned files without host sudo.
- **Excludes `data/media`** — that's the 923 GB Plex library on the T5; backing
  it up would blow out the disk. The archive is ~780 MB (mostly Plex metadata).
- Scheduled nightly at 03:30 via **Callum's user crontab** (`crontab -l`).
- Destination `DOCKER_BACKUP_DEST` = `~/backups` on the **NVMe**. Note: this is
  the same disk as the config data, so it protects against accidental
  breakage/corruption but NOT NVMe failure. The T5 is full of media and can't
  serve as the backup target — a proper off-machine target (NAS/cloud) is still
  a TODO. Media itself is not backed up (typical for a media library).

## Pending / known TODOs

- **HA media mount mismatch:** `compose.yaml` mounts `/mnt/ssd:/media/ssd:ro`
  into HA, but the T5 is actually at `data/media` and `/mnt/ssd` is empty/not
  mounted — so HA sees nothing there. Fix: change that volume to
  `${DATA_ROOT}/media:/media/ssd:ro`, or remove the line.
- **Off-machine backup target:** backups are on the NVMe only (no protection vs
  NVMe failure). Add a NAS/cloud destination.
- Plex first-run: sign in / claim + create libraries pointing at `data/media`
  (T5). Media disk is already mounted and full.
- Cockpit-behind-Caddy needs `/etc/cockpit/cockpit.conf` Origins allow-list
  (see README) — direct `:9090` works regardless.

## Done

- Repo pushed to `git@github.com:caltho/homelab.git` (branch `main`).
- `SAMBA_PASS` set to a random value in `.env`.
- 3 WiZ bulbs added to HA; nightly backups scheduled.
- 2 Meross MSS310 plugs added to HA via the `meross_lan` custom integration
  ("Bathroom Grow Light" @ .103, "Tower Lamp" @ .204). Local LAN control (port
  80 open on both) with a Meross cloud profile just for the device key.
  ⚠️ `meross_lan` was installed **manually** into `data/homeassistant/config/
  custom_components/meross_lan` (HACS's own download failed with a conflict), so
  **HACS will NOT auto-update it** — to upgrade, replace that folder with a newer
  release from `github.com/krahabb/meross_lan` and restart HA.
