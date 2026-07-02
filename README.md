# Homelab Docker stack

Compose stack for a home server: Home Assistant, Plex (with Intel Quick Sync),
Samba, and Caddy as a reverse proxy.

## Services

| Service        | Network      | Access                                  |
| -------------- | ------------ | --------------------------------------- |
| Home Assistant | host         | http://<host>:8123 · https://ha.home.lan   |
| Plex           | host         | http://<host>:32400/web · https://plex.home.lan |
| Samba          | bridge :445  | `\\<host>\Media`                        |
| Caddy          | bridge 80/443| reverse proxy (internal CA by default)  |

## Layout

```
compose.yaml        # the stack
.env                # secrets + config (gitignored)
.env.example        # template
caddy/Caddyfile     # reverse proxy config
data/               # config volumes + media (gitignored, created at runtime)
```

## First run

1. Install Docker Engine + Compose plugin (see below).
2. Edit `.env` — at minimum set `SAMBA_PASS`, and `TZ`/`DOMAIN` to taste.
3. (Optional) grab a Plex claim token from https://plex.tv/claim and put it in
   `PLEX_CLAIM` (expires in ~4 minutes, so do it right before starting).
4. `docker compose up -d`

## Notes

- **Home Assistant** runs in host network mode (required for device discovery).
  To use it behind Caddy, add to its `configuration.yaml`:

  ```yaml
  http:
    use_x_forwarded_for: true
    trusted_proxies:
      - 172.16.0.0/12   # docker bridge networks
  ```

- **Plex Quick Sync**: `/dev/dri` is passed through and the container joins the
  `render` group (`RENDER_GID` in `.env`). Enable "Use hardware acceleration
  when available" in Plex → Settings → Transcoder (requires Plex Pass).

- **Caddy** uses an internal CA by default (self-signed certs for `*.home.lan`).
  Trust its root CA on client devices, or switch to Let's Encrypt — see the
  comments in `caddy/Caddyfile`.

## Install Docker (Ubuntu 24.04)

```sh
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER   # log out/in afterwards to use docker without sudo
```
