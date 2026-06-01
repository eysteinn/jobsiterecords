# Deployment (single VPS)

Runs the Phase 2 stack: **web**, **api**, **Postgres**, and **MinIO**, routed through **Traefik** already running on the host.

The marketing site in `landing/` stays on its own host (Apache + PHP at jobsiterecords.com).

## Prerequisites

- Docker Engine and Compose v2 on the server
- **Traefik** running with the Docker provider enabled
- An **external Docker network** shared with Traefik (default name: `traefik`)
- DNS A/AAAA records for `APP_HOST`, `API_HOST`, and `MEDIA_HOST` pointing at the Traefik host
- Traefik `entryPoints` and `certificatesResolvers` names that match `.env.deploy` (`TRAEFIK_ENTRYPOINT`, `TRAEFIK_CERT_RESOLVER`)

Create the network if it does not exist yet:

```bash
docker network create traefik
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

## Updates

```bash
git pull
docker compose -f docker-compose.deploy.yml --env-file .env.deploy up -d --build
```

If you change `NEXT_PUBLIC_API_URL`, rebuild the **web** image (`--build`).

## Local dev

Use the root `docker-compose.yml` instead — hot-reload, published DB/MinIO ports, dev secrets.
