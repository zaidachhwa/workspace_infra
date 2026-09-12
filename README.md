# Cloud Workspace — Infrastructure

This repo holds everything needed to deploy and operate the Cloud Workspace
platform, *except* the application code itself:

- `docker-compose.yml`, `.env.example` — the platform stack (mongo, backend,
  frontend, Traefik)
- `infra/docker/` — Dockerfiles for the workspace images (what a workspace
  container actually is)
- `infra/nginx/` — the nginx site configs that route the real domain to the
  platform
- `infra/scripts/` — platform database backup/restore
- `docs/` — architecture, security, day-to-day deployment, and a full
  from-scratch server setup guide

## The three repos

| Repo | Contains |
|---|---|
| `workspace_backend` | Express API |
| `workspace_frontend` | Next.js dashboard |
| `workspace_infra` (this one) | Everything else needed to run them |

## Start here

- Setting up on an **existing** server (deploying a code change, troubleshooting): [`docs/deployment.md`](docs/deployment.md)
- Setting up a **brand new** server from scratch: [`docs/server-setup.md`](docs/server-setup.md)
- Understanding how the system fits together: [`docs/architecture.md`](docs/architecture.md)
- Security model and known gaps: [`docs/security.md`](docs/security.md)

`AGENT.md` at the repo root defines the coding standards and tech stack
conventions used across all three repos.
