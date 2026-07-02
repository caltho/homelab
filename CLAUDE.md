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

- `scripts/backup.sh` tars `~/docker` (incl. `data/` + `.env`) to a timestamped
  `.tar.gz`, keeping the last 7. Runs tar inside a container (image `caddy:2`) so
  it can read root-owned files without host sudo.
- Scheduled nightly at 03:30 via **Callum's user crontab** (`crontab -l`).
- Destination is `DOCKER_BACKUP_DEST` (currently `~/backups` on the NVMe — same
  disk as the data, so it does NOT protect against disk failure yet). Intended
  upgrade: mount the **Samsung T5** SSD (`/dev/sda1`, exFAT, UUID `A463-7C51`)
  and repoint `DOCKER_BACKUP_DEST` at it. Mounting needs sudo (Callum runs it).

## Pending / known TODOs

- Move backups to the Samsung T5 (needs sudo mount + fstab entry).
- Push this repo to a private GitHub remote (SSH key generated at
  `~/.ssh/id_ed25519`; awaiting repo creation).
- Plex first-run: sign in / claim + point a library at the T5 media (the T5 is
  the intended Plex media disk; wasn't touched yet).
- Cockpit-behind-Caddy needs `/etc/cockpit/cockpit.conf` Origins allow-list
  (see README) — direct `:9090` works regardless.
- `SAMBA_PASS` was set to a random value in `.env`.
