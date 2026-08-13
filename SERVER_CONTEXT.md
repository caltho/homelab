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
  (932 GB, 495 GB used / 437 GB free as of 2026-08-12): Plex library, Soulseek
  downloads, *arr media. Biggest consumers: `PLEX` 271 GB, `PLEX TV` 124 GB,
  `servarr` 24 GB, `Old Laptop` 22 GB, `Private` 22 GB, `Music` 16 GB.

## Backups

- **restic** nightly → encrypted repo on the T5. Covers `~/docker` **and**
  `~/claude-telegram-bridge`. ⚠️ `~/media-stack` and `~/slskd` are **not** in
  restic yet (their configs would be lost on disk failure — TODO).
- Nightly tarball of `~/docker` → `~/backups` (NVMe).
- Nightly `git push` of the `~/docker` recipe → GitHub (`caltho/homelab`).

## This bot (Geoffrey)

- Telegram bot backed by the Claude Agent SDK. Allowlisted to **two** people:
  **Callum** (admin) and **Lucy**, who lives here but does not administer anything.
- **Two personas, one bot** (`USER_PROFILES` in the bridge's `.env`):
  - Callum → `technical`: terse, shell/paths/logs, live tool-call stream.
  - Lucy → `friendly`: plain English, never sends commands, code, paths or log
    output, keeps answers short, invites follow-up questions. Her replies are also
    stripped of markdown and code blocks in code, not just by instruction.
  - Both have the **same permissions**; only the voice and the output differ.
- Writes are allowed in `~/docker` (`/workspace`, the cwd) **and** in
  `~/media-stack` (`/stacks/media-stack`) and `~/slskd` (`/stacks/slskd`).
- A `PreToolUse` veto blocks: writes outside those three roots, `rm -r` on a stack
  root or anything outside them, `git push`, and stopping/killing containers.
- Docker access is via a least-privilege broker (bot has no socket):
  - `docker-list` — list all containers, any stack.
  - `docker-logs <name> [tail]` — logs for any container.
  - `restart-service <name>` — **restart only**, no stop/kill. Allowlist now covers
    all four stacks except the bridge and broker themselves: homeassistant, plex,
    samba, portainer, caddy, sonarr, radarr, prowlarr, overseerr, qbittorrent,
    media-gluetun, slskd, slskd-bot, gluetun. Run with no argument to print the list.
- `plex <command>` — direct Plex control via its API (token read from Plex's own
  `Preferences.xml`): `libraries`, `scan <library|all>` (the fix for "my new film
  isn't showing up"), `refresh <library>`, `sessions` (who's watching right now),
  `recent [n]`. Prefer a scan over restarting Plex — it's invisible to viewers.
- **Home Assistant** has no API token, so the bot cannot read or set live device
  state. It changes HA by editing `data/homeassistant/config/*.yaml` and then
  `restart-service homeassistant`. Some files there are root-owned and will refuse
  to be written (notably anything new in `dashboards/` and `.storage/`).
- Can push proactive Telegram messages to Callum with `notify <message>` (e.g.
  progress on background work, or handing over anything that needs root). Errors in
  Lucy's chat are auto-reported to Callum.
