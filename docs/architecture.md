# Architecture

## What this is

A persistent cloud development workspace platform. A user creates a workspace,
gets a real Docker container running a browser IDE (code-server) with a
persistent volume, and can stop working from one device and pick up on
another without losing anything. The core mental model, which every design
decision below follows from:

> A container is disposable compute. A volume is persistent user data.
> Losing/recreating a container must never lose the volume.

## Components

```
Internet
   │
   ▼
nginx (host-level, port 80/443, terminates TLS, fronts other sites too)
   │
   ├─ workspace.<domain>          → frontend container   (Next.js dashboard)
   ├─ api.<domain>                → backend container    (Express API)
   └─ *.<domain>                  → Traefik               → the matching workspace container
                                       (routes by Host header via Docker labels)

backend container
   ├─ MongoDB (platform metadata: users, workspaces, events, snapshots, templates)
   └─ Docker socket (creates/starts/stops/deletes workspace containers)

workspace container (one per workspace)
   ├─ code-server (browser IDE + terminal)
   ├─ Node.js + git
   ├─ [Full Stack template only] mongod, bundled in the same container
   └─ named Docker volume mounted at /home/coder/project (the only persistent part)
```

## Why two Docker networks

- **`cloudworkspace-platform`** — backend ↔ mongo only. Workspace containers
  are never on this network; they have no path to the platform's own database.
- **`cloudworkspace-proxy`** — Traefik ↔ every workspace container. This is
  how a workspace gets routed to without publishing any host port itself —
  Traefik discovers it via Docker labels set at container creation
  (see `backend/src/services/docker.service.js`).

Workspace containers currently share this one network with each other (not
yet isolated from one another) — see `docs/security.md` for that as a known
gap.

## Data model (MongoDB)

- **User** — email, bcrypt password hash, refresh token hashes (for logout/rotation).
- **Workspace** — owner, name, slug, status, template ref, containerId,
  accessDomain, resource limits, encrypted environment variables,
  accessPasswordEncrypted (the code-server login password).
- **WorkspaceEvent** — append-only audit log (created/started/stopped/deleted/
  git-import/snapshot events), one per lifecycle action.
- **WorkspaceSnapshot** — metadata only (workspace ref, generated filename,
  size, timestamp). The actual `.tar.gz` lives in the shared
  `cloudworkspace-backups` Docker volume, not in MongoDB.
- **WorkspaceTemplate** — name + Docker image + config. What "Node.js" vs
  "Full Stack" actually means is entirely which image gets used.

## The disposable-container pattern

Every operation that needs to "reach into" a workspace's files without a
long-running target container (snapshot create/restore/delete) follows the
same pattern: spin up a short-lived Alpine (or Mongo, for platform backups)
container, mount the relevant volume(s), run one command, remove the
container. See `runOneOffContainer` in `docker.service.js`. This is also how
platform database backups work (`infra/scripts/backup-platform-db.sh`) — same
idea, applied to the platform's own Mongo data instead of a workspace volume.

Git import (cloning a repo into a *running* workspace at creation time) is
the one operation that instead uses `docker exec` directly into the
already-running target container, since one already exists at that point.

## Request flow: creating a workspace

1. Browser → `POST /api/workspaces` (dashboard, cookie-authenticated)
2. Backend validates the profile (small/medium/large — client never sends
   raw resource numbers, only picks a name the server maps to real limits)
3. Backend creates a Mongo record (`status: creating`)
4. Backend creates a named Docker volume (`cw-volume-<slug>`)
5. Backend creates the container from the template's image, with:
   - resource limits (CPU/memory/PIDs) matching the chosen profile
   - `CapDrop: ALL`, non-root, no privileged mode, no host Docker socket
   - Traefik labels for `Host(\`<slug>.<domain>\`)`
   - the volume mounted at `/home/coder/project`
6. Backend starts the container, updates the Mongo record to `running`
7. If a git repo URL was given, `docker exec git clone` into it (best-effort —
   failure doesn't fail workspace creation, it's surfaced as a warning)
8. Response includes `accessUrl` (`https://<slug>.<domain>`) and a generated
   `accessPassword` for code-server's own login

## Two-tier templates

Both current templates (Node.js, Full Stack) are built from the same base
(`infra/docker/workspace/Dockerfile`) — code-server + Node 22 + git, on top
of the official `codercom/code-server` image (Debian 13 "trixie"). Full Stack
extends that base (`infra/docker/workspace-fullstack/Dockerfile`) by adding a
real `mongod` that starts alongside code-server in the same container (see
`start.sh` there) — deliberately *not* a separate companion container, to
keep the "one container = one workspace" model intact everywhere else in the
codebase (a single `containerId` per workspace, one Traefik route, one
volume). Mongo's data lives inside the same project volume
(`.mongodb-data/`), so it persists exactly like the rest of the workspace.

**Non-obvious thing worth knowing**: MongoDB has not published server
binaries for Debian 13 yet as of when this was built — only their Debian 12
("bookworm") build. glibc is backward-compatible, so that build runs fine on
the trixie base; this was verified directly, not assumed. If MongoDB ships
trixie support later, the apt source line in the fullstack Dockerfile could
be updated, but there's no urgency — the current setup works.

## What's deliberately NOT built

Kubernetes, multi-server scheduling, autoscaling, a marketplace, complex
billing, enterprise SSO, multi-region, a custom editor — all explicitly out
of scope for this MVP per the original spec. Don't reach for these unless
actual scale demands it.
