# Security

This platform executes arbitrary user-controlled code inside workspace
containers. Treat every workspace as untrusted compute. This document
describes what's actually enforced today, and — just as importantly — what
isn't yet, so nobody assumes protection that doesn't exist.

## Container isolation (workspace containers)

Enforced on every workspace container, set at creation in
`backend/src/services/docker.service.js`:

- **Non-root**: runs as the image's `coder` user (uid 1000), never root.
- **`CapDrop: ALL`**: no Linux capabilities. Not even the container's own
  root (if something did run as root) could `chown`/`setuid`/etc. — this is
  exactly why fixing a permission problem on a workspace volume requires a
  *separate* throwaway container with normal capabilities, not `docker exec`
  into the workspace container itself.
- **`Privileged: false`**, **`SecurityOpt: no-new-privileges`**.
- **No host Docker socket mount** — a workspace container has no way to
  control Docker itself, unlike the backend, which legitimately needs this
  access (it's the trusted control plane, never a workspace container).
- **Resource limits**: CPU (`NanoCpus`), memory, and PID count are all capped
  per the chosen profile (small/medium/large) and enforced by Docker/cgroups,
  not just tracked as metadata. Verified directly via `docker inspect`
  against a real running container, not assumed from the API call.
- **No published host ports**. The only way to reach a workspace is through
  Traefik, discovered via Docker labels — there's no direct host:port path in.

## Known gap: workspace containers share one network

All workspace containers currently sit on the same `cloudworkspace-proxy`
Docker network (so Traefik can reach all of them). Docker's default bridge
networking means containers on the same network *can* reach each other by
IP. This means one workspace could theoretically probe another workspace's
container directly, bypassing the platform entirely. Not yet mitigated —
worth addressing before opening this to unrelated/untrusted users (Docker
network policies, or one network per workspace, would close this).

## Authentication & authorization

- Passwords hashed with bcrypt (`bcryptjs`, 12 rounds) — plaintext is never stored.
- JWT access token (15 min) + refresh token (7 days), both `httpOnly`,
  `Secure` (in production), `SameSite=Lax` cookies — never accessible to
  frontend JavaScript, so an XSS bug can't steal them outright.
- Refresh tokens are stored server-side as SHA-256 hashes, not the raw token
  — a database leak alone can't be replayed as a valid session.
- **Every workspace operation checks ownership.** `getOwnedWorkspace` queries
  by `{_id, user}` together — a workspace ID alone is never sufficient
  authorization. A request for another user's workspace gets a **404, not
  403** — deliberately, so the API never confirms whether an ID even exists
  for someone who doesn't own it. Verified directly with a real second
  account against production, not just reasoned about.

## Secrets

- Workspace environment variables are encrypted at rest with AES-256-GCM
  (`backend/src/utils/encryption.js`) — the raw value is never stored in Mongo.
- Encrypted values are **never** returned by the API except through the one
  deliberate path that needs to (injecting them into a workspace container at
  creation/start). The list-environment-variables endpoint returns key names
  only, never values.
- The generated code-server login password (`accessPassword`) is treated
  differently — it's a platform-managed credential for entering your own
  workspace, not user secret material, so it *is* decrypted back and returned
  to the owning user (needed to actually use the IDE).
- JWT secrets and the env-encryption key live only in `backend/.env`
  (`.gitignore`d, never committed) — generated per-deployment, never reused
  between local dev and production.
- Application logs never include secret values, passwords, or full request
  bodies — only error messages, which come from Docker/git/Mongo, not from
  anything containing user secrets.

## Reverse proxy / TLS

- Every public-facing hostname (dashboard, API, every individual workspace)
  is HTTPS-only in production.
- The dashboard and API certs (`workspace.<domain>`, `api.<domain>`) were
  issued via certbot's nginx plugin and **auto-renew**.
- The wildcard cert (`*.<domain>`, needed for individual workspace
  subdomains) required proving DNS control via a manual TXT record
  (`certbot certonly --manual --preferred-challenges dns`) — **this one does
  NOT auto-renew.** It must be repeated manually before expiry (Let's
  Encrypt certs last 90 days). If this lapses, every workspace URL breaks
  with a certificate error while the dashboard/API keep working fine — that
  asymmetry can be confusing if you forget this is manual. Check current
  expiry with `sudo certbot certificates` on the server.

## Known gaps — review before opening this to untrusted/public users

These are explicitly **not** done yet, carried over from an infrastructure
security audit run against the live server:

- SSH (port 22) is open to any IP. Should be restricted to known IPs or a VPN.
- Prometheus and Grafana (from unrelated projects on the same shared server)
  are publicly reachable. Not this platform's containers, but worth knowing
  they're exposed on the same box.
- No rate limiting on auth endpoints (login/register) — brute-force
  protection is not implemented.
- No abuse/quota policy — a user could create unlimited workspaces up to
  server capacity. Fine for a small trusted user base; not fine at
  public-signup scale.
- No automated intrusion/anomaly monitoring beyond what the box's existing
  Monarx agent (unrelated to this platform) provides.

None of these block continuing to build features for known/trusted users.
They matter before advertising this to strangers.
