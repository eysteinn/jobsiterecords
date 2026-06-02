# Deployment (single VPS)

Runs the Phase 2 stack: **web**, **api**, **Postgres**, and **MinIO**, routed through **Traefik** already running on the host.

The marketing site in `landing/` stays on its own host (Apache + PHP at jobsiterecords.com).

## Prerequisites

- Docker Engine and Compose v2 on the server
- **Traefik** running with the Docker provider enabled
- An **external Docker network** shared with Traefik (e.g. `traefik_reverse_proxy` on a shared VPS — see `TRAEFIK_NETWORK` in `.env.deploy.example`)
- DNS **A** records for `APP_HOST`, `API_HOST`, and `MEDIA_HOST` pointing at the Traefik host (not CNAME to the marketing apex on another host)
- Traefik `entryPoints` and `certificatesResolvers` names that match `.env.deploy` (`TRAEFIK_ENTRYPOINT`, `TRAEFIK_CERT_RESOLVER`)

Create the network if it does not exist yet (use the same name as `TRAEFIK_NETWORK`):

```bash
docker network create traefik_reverse_proxy
```

## First boot

From the repo root on the server:

```bash
cp .env.deploy.example .env.deploy
# Edit .env.deploy: secrets, domains, TRAEFIK_* to match your Traefik config

docker compose -f docker-compose.deploy.yml --env-file .env.deploy up -d --build
```

Check:

- `https://<API_HOST>/health` → `ok`
- `https://<APP_HOST>/` → dashboard

## Traefik labels

Compose attaches `web`, `api`, and `minio` to the external `TRAEFIK_NETWORK` and sets router rules `Host(\`…\`)` per service. Router names are prefixed `sitelog-` to avoid clashes with other stacks on the same host.

If your Traefik setup differs (no cert resolver, different entrypoint names, file-based routes instead of Docker labels), adjust the labels in `docker-compose.deploy.yml` or use a Compose override file.

On a shared Traefik host (e.g. with Aldadrift), set `TRAEFIK_NETWORK` to the existing external network (often `traefik_reverse_proxy`). Router labels include `tls=true` and `tls.certresolver=…` like the other stacks.

### TLS / DNS troubleshooting

- **`app.*` works but `api.*` shows wrong cert or `TRAEFIK DEFAULT CERT`:** DNS for `api` and `media` must be **A** records to the Traefik host (not CNAME to the marketing site on 1984). After DNS is correct, recreate `api`/`minio` and check Traefik ACME logs.
- **Verify from a machine:** `dig @8.8.8.8 api.<domain> +short` and `curl -sS https://api.<domain>/health` → `ok`.
- **Force hit Beelink (bypass stale resolver cache):** `curl -sS --resolve api.<domain>:443:<server-ip> https://api.<domain>/health` — if this still shows `TRAEFIK DEFAULT CERT`, the Docker router labels or `API_HOST` in `.env.deploy` are wrong, not DNS.

## Updates

```bash
git pull
docker compose -f docker-compose.deploy.yml --env-file .env.deploy up -d --build
```

If you change `NEXT_PUBLIC_API_URL`, rebuild the **web** image (`--build`).

## Local dev

Use the root `docker-compose.yml` instead — hot-reload, published DB/MinIO ports, dev secrets.
