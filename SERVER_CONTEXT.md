# SERVER_CONTEXT.md — bongripper home server

> Canonical, high-level map of Callum's home server. This file is injected into
> the Telegram bot's context on every message. **Keep it accurate:** when the
> server changes, update this file. Personal homelab — never involve work tools.

## Host

- Machine **bongripper**, Ubuntu 24.04. LAN IP **192.168.50.96**.
- Remote access via **Tailscale** (tailnet IP `100.101.181.46`, Tailscale SSH).
- `sudo` needs a password (no passwordless sudo) — anything needing root must be
  run by Callum in a real terminal.
- Docker from a plain shell may need the `sg docker -c '...'` wrapper.

## Docker stacks (4 Compose projects)

| Stack | Dir | Containers |
| --- | --- | --- |
| **homelab** | `~/docker` | homeassistant, plex, samba, portainer, caddy |
| **media-stack** | `~/media-stack` | media-gluetun, qbittorrent, sonarr, radarr, prowlarr, overseerr |
| **slskd-stack** | `~/slskd` | gluetun, slskd, slskd-bot |
| **claude-telegram-bridge** | `~/claude-telegram-bridge` | claude-telegram-bridge (this bot), claude-restart-broker |

### homelab (`~/docker`)
- **homeassistant** — host network, `:8123`, `https://ha.home.lan`. Config is
  root-owned (edit via `docker exec homeassistant …`, not host sudo).
- **plex** — host network, `:32400/web`, `https://plex.home.lan`. Intel Quick Sync.
- **samba** — bridge `:445`, `\\192.168.50.96\Media`.
- **portainer** — bridge `:9443`, `https://portainer.home.lan`.
- **caddy** — reverse proxy 80/443, internal CA for `*.home.lan` (browsers warn
  until the root cert is trusted).
- Cockpit runs at `:9090` as a **host service (not Compose)**.

### media-stack (`~/media-stack`) — automated movie/TV request + download
- **media-gluetun** — ProtonVPN (WireGuard) tunnel with kill-switch; publishes
  qBittorrent's WebUI on `:8080`. If it stops, qBittorrent loses all network.
- **qbittorrent** — `network_mode: service:gluetun` (all torrent traffic via VPN).
  WebUI `http://192.168.50.96:8080`.
- **prowlarr** `:9696` (indexers), **radarr** (movies), **sonarr** (TV),
  **overseerr** (request UI).
- Storage: downloads on ext4; final media on the **T5 exFAT** drive. exFAT has **no
  hardlinks**, so *arr apps copy on import and qBittorrent auto-removes torrents
  after a seed goal. Plex reads the same library.

### slskd-stack (`~/slskd`) — Soulseek + Telegram wishlist bot
- **gluetun** — ProtonVPN (WireGuard) with port-forwarding; publishes slskd's UI on
  `:5030` (LAN only).
- **slskd** — Soulseek daemon, `network_mode: service:gluetun` (via VPN kill-switch).
  Downloads land under `~/docker/data/media/Soulseek/`; shares `Music/` read-only.
- **slskd-bot** — a *separate* Telegram bot (Python) for a Soulseek wishlist; NOT on
  the VPN; talks to slskd at `gluetun:5030`; SQLite wishlist in `bot/state`.

> Two independent ProtonVPN `gluetun` containers (one for torrents, one for
> Soulseek). Both must stay `healthy` or their downloader loses network.

## Storage

- OS + all container config on the internal **NVMe**.
- **Samsung T5 SSD** (exFAT, UUID `A463-7C51`) mounted at `~/docker/data/media`
  (~923 GB, near full): Plex library, Soulseek downloads, *arr media.

## Backups

- **restic** nightly → encrypted repo on the T5. Covers `~/docker` **and**
  `~/claude-telegram-bridge`. ⚠️ `~/media-stack` and `~/slskd` are **not** in
  restic yet (their configs would be lost on disk failure — TODO).
- Nightly tarball of `~/docker` → `~/backups` (NVMe).
- Nightly `git push` of the `~/docker` recipe → GitHub (`caltho/homelab`).

## This bot (GeoffreyBot)

- Telegram bot backed by the Claude Agent SDK. Allowlisted to Callum only.
- Works read-write inside `~/docker` (mounted `/workspace`). It does **not** have
  the other stacks' files mounted — but it CAN see their containers and logs.
- A `PreToolUse` veto blocks: writes outside the workspace, `rm -r` on system
  paths, `git push`, and stopping/killing homeassistant/plex.
- Docker access is via a least-privilege broker (bot has no socket):
  - `docker-list` — list all containers, any stack.
  - `docker-logs <name> [tail]` — logs for any container.
  - `restart-service <name>` — restart, allowlist: homeassistant, plex, samba,
    portainer, caddy (restart only; no stop/kill).
- Can push proactive Telegram messages to Callum with `notify <message>` (e.g.
  progress/completion of background work).
