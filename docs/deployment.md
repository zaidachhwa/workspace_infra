# Deployment (existing server)

This covers day-to-day operations on a server that's already set up. If
you're provisioning a **new** server from scratch (migrating providers,
recovering from a lost server), see `server-setup.md` instead — this
document assumes everything there is already done once.

## Repository layout on the server

Three independent git repos, cloned side by side in one working directory
(here, `~/cloud_workspace_zaid/`, but the name doesn't matter):

```
cloud_workspace_zaid/
├── backend/            ← github.com/<you>/workspace_backend
├── frontend/           ← github.com/<you>/workspace_frontend
├── infra/              ← github.com/<you>/workspace_infra (this repo)
├── docker-compose.yml  ← from workspace_infra
└── .env                ← NOT committed anywhere; compose-level secrets
```

`backend/.env` and the root `.env` are both server-local, generated once
during setup, never committed. Templates for both live in
`backend/.env.production.example` and this repo's `.env.example`.

## Deploying a code change

```bash
cd ~/cloud_workspace_zaid
git -C backend pull origin main     # if backend changed
git -C frontend pull origin main    # if frontend changed
sudo docker compose up -d --build   # rebuilds whichever service(s) changed
```

`docker compose up -d --build` only rebuilds services whose build context
actually changed — mongo and the proxy won't restart just because you
touched backend code. You can also target one service specifically:
`sudo docker compose up -d --build backend`.

**If `infra/` itself changed** (docker-compose.yml, nginx configs, the
workspace Dockerfiles, the backup scripts) — pull that repo too and re-copy
whichever files changed into place; there's no single command for this since
nginx configs live outside Docker entirely. See the relevant section in
`server-setup.md` for exact file locations.

## Verifying a deploy

```bash
sudo docker compose ps                              # all four containers "Up"
curl -s http://127.0.0.1:4001/health                # backend direct (bypasses nginx)
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3005/   # frontend direct
```

Then through the real domain: log into the dashboard, create a test
workspace, confirm its IDE opens, delete it.

## Common issues (things that actually happened building this)

**`permission denied while trying to connect to the docker API`** — you're in
an SSH session that predates being added to the `docker` group. Either
reconnect (`exit`, SSH back in) or just prefix commands with `sudo`.

**A pasted multi-line command didn't do anything except print itself back** —
if a command block is wrapped in an outer `cat <<'EOF' ... EOF` (used to
*display* a script), don't paste the outer wrapper too — only the commands
inside it are meant to run. This bit us more than once.

**Traefik logs `client version X is too old`** — its bundled Docker client
rejected this host's Docker Engine API version. Check
`docker version --format '{{.Server.APIVersion}}'` and update
`TRAEFIK_DOCKER_API_VERSION` in the root `.env`, then
`sudo docker compose up -d --build proxy`. (We also had to bump the Traefik
image itself from v3.2 to v3.7 — an older Traefik release may not negotiate
a very new Docker Engine's API version at all, regardless of this env var.)

**`No such image: alpine:latest`** the first time a snapshot is created on a
fresh server — the backend now auto-pulls this on first use
(`ensureHelperImage` in `docker.service.js`), so this should self-resolve.
If it doesn't, `docker pull alpine:latest` manually and retry.

**A workspace won't delete, "volume is in use"** — a leftover helper
container (from snapshot create/restore) still references the volume.
`docker ps -a --filter volume=cw-volume-<slug>` to find it,
`docker rm <container>`, then retry the delete. This should no longer happen
going forward (fixed via `try/finally` around helper container cleanup), but
if it ever recurs, this is the manual fix.

## Environment variables reference

**Root `.env`** (read by `docker-compose.yml` itself, not passed into containers):

| Variable | Purpose |
|---|---|
| `DOCKER_GID` | Host's `docker` group GID, so the non-root backend container can reach `docker.sock`. Get with `getent group docker \| cut -d: -f3`. |
| `TRAEFIK_DOCKER_API_VERSION` | Must match (or be below) this host's Docker Engine API version. |
| `NEXT_PUBLIC_API_URL` | Public API URL — baked into the frontend at *build* time (browser calls it directly). |
| `BACKEND_PORT` / `FRONTEND_PORT` / `PROXY_PORT` | Host-local ports nginx reverse-proxies to. |

**`backend/.env`** (injected into the backend container via `env_file`):

| Variable | Purpose |
|---|---|
| `MONGO_URI` | Must use the Docker service name (`mongo`), not `localhost`. |
| `CORS_ORIGIN` | Exact dashboard origin — must match what the browser sends. |
| `ACCESS_TOKEN_SECRET` / `REFRESH_TOKEN_SECRET` | JWT signing keys — generate fresh per deployment, never reuse. |
| `ENV_ENCRYPTION_KEY` | 32-byte hex — encrypts workspace environment variables at rest. Generate fresh per deployment; **do not lose this** — losing it makes existing encrypted env vars unrecoverable. |
| `BASE_WORKSPACE_DOMAIN` | The real domain workspace subdomains are built from. |
| `WORKSPACE_PROTOCOL` | `https` in production, `http` for local dev without TLS. |
| `ADMIN_EMAILS` | Comma-separated. Matching accounts auto-promote to admin on register/login — set to your own email to bootstrap the first admin. |

## Running tests

```bash
cd backend
npm test
```

Real MongoDB + real Docker, no mocks — this will create and delete a real
throwaway container during the run. Safe to run against the local dev Mongo;
avoid running against production's Mongo unless you're fine with a
short-lived test workspace container appearing and disappearing there.

## Backups

See `infra/scripts/backup-platform-db.sh`, `restore-platform-db.sh`,
`list-platform-backups.sh` and the cron entry set up during server setup.
Covers the **platform's own database** (users/workspaces/events) —
workspace *volume* snapshots are a separate, in-app feature (the Snapshots
panel on each workspace card), unrelated to these scripts.
