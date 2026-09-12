# Server Setup — From Scratch

Follow this if you're provisioning a **brand new server** — migrating
providers, recovering from a lost server, or spinning up a second
environment. It assumes nothing about the new box except that you have root
SSH access. Every step below is exactly what was actually done building this
platform the first time, including the mistakes, so you don't have to
rediscover them.

Where you see `<domain>`, substitute your real domain (e.g. `workspace.keyset.in`).
Where you see `<ip>`, substitute the new server's IP.

## Phase 0 — Inspect the new server

```bash
hostnamectl
lscpu | grep -E "Model name|CPU\(s\)"
free -h
df -h
docker --version   # very likely "not found" on a fresh box — that's fine, Phase 2 installs it
```

Record CPU/RAM/disk. This platform is not resource-hungry for a small number
of workspaces — the original box (8 vCPU / 31GB RAM / 400GB disk) had huge
headroom; a much smaller VPS would run this fine for personal/small-team use.

## Phase 1 — DNS

At your domain's DNS provider, add two records pointing at the new server's IP:

| Type | Host | Value |
|---|---|---|
| A | `workspace` (or whatever subdomain you use) | `<ip>` |
| A | `*.workspace` | `<ip>` |

Both `workspace.<domain>` and `api.<domain>` resolve via the first record
(DNS doesn't distinguish subdomains — that routing happens later at the
nginx layer). The wildcard covers every individual workspace.

DNS propagation can take a few minutes; you can move on to other phases
while waiting, but SSL (Phase 6) needs it to have actually propagated.

**Common mistake**: double-check the IP you're given/copying is actually
correct before wiring DNS to it — a single wrong digit (e.g. `.236` vs
`.234`) produces confusing symptoms that look exactly like a firewall
problem (everything times out identically — your own browser, SSL
validation, everything), and can burn a lot of time before you think to
question the IP itself rather than the network path.

## Phase 2 — Install Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
```

Use Docker's **official repo**, not the `docker.io` Ubuntu package — the
official one includes the `docker compose` v2 plugin this whole setup
assumes (`docker compose ...`, not `docker-compose ...`).

**The group membership change needs a new login session** — either fully
disconnect and reconnect SSH, or run `newgrp docker` to get it in your
current shell. Until then, every `docker` command fails with `permission
denied while trying to connect to the docker API` — this is not a real
problem, just an unrefreshed session. `sudo docker ...` works immediately
regardless, if you'd rather not bother with the group at all.

## Phase 3 — Firewall (the part most likely to trip you up)

Check the **OS-level** firewall:

```bash
sudo ufw status verbose
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable   # if not already active
```

**This is not enough on most cloud/VPS providers.** There is very likely a
**second, separate network firewall** enforced outside the operating system
entirely — a "Cloud Firewall," "Security Group," or similar, configured
through the provider's own web dashboard, not visible or controllable via
SSH at all. `ufw` can report ports as open while this second layer silently
drops everything anyway.

**How this was actually diagnosed last time**: `ufw` showed 80/443 open, yet
nothing external could connect — not a browser, not Let's Encrypt's
validation servers, nothing — while SSH worked fine. The giveaway was that
literally nothing external could get through despite the OS insisting it was
open. If you hit this: log into your provider's control panel, find the
firewall/security-group section for this specific server instance, and
confirm 22, 80, and 443 are explicitly allowed from "Anywhere"/`0.0.0.0/0`.
**Add all three ports in the same action if the panel replaces the whole
rule set on save** — adding 80/443 in one save and 22 in a separate later
save can each silently drop whatever wasn't included in *that* particular
save, briefly locking out SSH or re-blocking HTTP in between.

Don't assume this is fixed just because you clicked "save" — reopen the
panel afterward and confirm the rules actually persisted.

## Phase 4 — Clone the repos

```bash
mkdir -p ~/cloud_workspace_zaid && cd ~/cloud_workspace_zaid
git clone https://github.com/<you>/workspace_backend.git backend
git clone https://github.com/<you>/workspace_frontend.git frontend
git clone https://github.com/<you>/workspace_infra.git infra_src

# infra_src contains docker-compose.yml, .env.example, and infra/ itself —
# copy them up to the working directory root so paths match what compose expects
cp infra_src/docker-compose.yml infra_src/.env.example .
cp -r infra_src/infra .
```

(Clone with explicit target directory names — `backend`/`frontend` — so they
match what `docker-compose.yml` expects as build contexts, regardless of
what the GitHub repo names themselves are.)

## Phase 5 — Configure and start the platform stack

```bash
cd ~/cloud_workspace_zaid

DOCKER_GID=$(getent group docker | cut -d: -f3)
TRAEFIK_API_VERSION=$(sudo docker version --format '{{.Server.APIVersion}}')

cat > .env <<EOF
DOCKER_GID=${DOCKER_GID}
TRAEFIK_DOCKER_API_VERSION=${TRAEFIK_API_VERSION}
NEXT_PUBLIC_API_URL=https://api.<domain>/api
BACKEND_PORT=4001
FRONTEND_PORT=3005
PROXY_PORT=8091
EOF

cp backend/.env.production.example backend/.env
sed -i "s#^ACCESS_TOKEN_SECRET=.*#ACCESS_TOKEN_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")#" backend/.env
sed -i "s#^REFRESH_TOKEN_SECRET=.*#REFRESH_TOKEN_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")#" backend/.env
sed -i "s#^ENV_ENCRYPTION_KEY=.*#ENV_ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")#" backend/.env
# Edit backend/.env by hand to set BASE_WORKSPACE_DOMAIN and CORS_ORIGIN to your real domain

# Build the workspace images — these are OUR OWN images, never on a public
# registry, so every new server must build them locally, once
sudo docker build -t cloudworkspace/dev-node:latest infra/docker/workspace
sudo docker build -t cloudworkspace/dev-fullstack:latest infra/docker/workspace-fullstack

sudo docker compose up -d --build
sleep 3
sudo docker compose ps   # all four containers should show "Up"

sudo docker exec cw_backend node src/db/seed.js   # creates the two workspace templates
```

**If `PROXY_HTTP_PORT`/`PROXY_PORT` needs to differ from 8091** because
something else on the box already uses it — check first with
`sudo ss -ltnp | grep :8091` — this is purely an internal handoff port
between nginx and Traefik, never exposed externally, so any free port works.

Verify directly, bypassing nginx entirely (isolates "did the stack start" from
"is nginx routing to it"):

```bash
curl -s http://127.0.0.1:4001/health
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3005/
```

## Phase 6 — nginx

```bash
cd ~/cloud_workspace_zaid
sudo cp infra/nginx/workspace.<domain>.conf /etc/nginx/sites-available/
sudo cp infra/nginx/api.workspace.<domain>.conf /etc/nginx/sites-available/
sudo cp infra/nginx/workspace-wildcard.<domain>.conf /etc/nginx/sites-available/

sudo ln -sf /etc/nginx/sites-available/workspace.<domain>.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/api.workspace.<domain>.conf /etc/nginx/sites-enabled/
sudo ln -sf /etc/nginx/sites-available/workspace-wildcard.<domain>.conf /etc/nginx/sites-enabled/

sudo nginx -t   # validates the ENTIRE config, including any other sites already on this box
sudo systemctl reload nginx
```

The three template configs in `infra/nginx/` have placeholder domains and
ports (`3005`, `4001`, `8091`) — edit them to match your actual domain and
whatever ports you set in Phase 5 if they differ from the defaults, *before*
copying them into `sites-available/`.

If this server already hosts other sites, `nginx -t` validates all of them
together — a passing result means you haven't broken anything already there.

Sanity check before trusting DNS/SSL:

```bash
curl -s -H "Host: workspace.<domain>" -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
curl -s -H "Host: api.<domain>" http://127.0.0.1/health
curl -s -H "Host: anything.workspace.<domain>" -o /dev/null -w "%{http_code}\n" http://127.0.0.1/
```

Expect `200`, a JSON health response, and `404` (correct — no workspace
named "anything" exists, but it proves the wildcard route reaches Traefik).

## Phase 7 — SSL

**Stage A — dashboard + API** (fully automated, auto-renews):

```bash
sudo apt-get install -y certbot python3-certbot-nginx   # likely already installed if this box hosts other sites
sudo certbot --nginx -d workspace.<domain> -d api.workspace.<domain>
```

**Stage B — the wildcard** (needed so individual workspace URLs get valid
HTTPS too). Wildcards can't use the simple method above — they require
proving DNS control:

```bash
sudo certbot certonly --manual --preferred-challenges dns -d "*.workspace.<domain>"
```

It will print a TXT record to add (`_acme-challenge.workspace.<domain>`) —
add it at your DNS provider, wait a minute or two for propagation, *then*
press Enter to continue. Note the certificate path it reports at the end
(commonly suffixed `-0001` if Stage A already claimed the plain domain name)
— you need it for the next step.

Wire the wildcard cert into the nginx config that's currently HTTP-only:

```bash
sudo tee /etc/nginx/sites-available/workspace-wildcard.<domain>.conf > /dev/null <<'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name *.workspace.<domain>;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name *.workspace.<domain>;

    ssl_certificate /etc/letsencrypt/live/<path-certbot-reported>/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/<path-certbot-reported>/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8091;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }
}
EOF
sudo nginx -t && sudo systemctl reload nginx
```

The `Upgrade`/`Connection` headers are load-bearing, not optional — without
them code-server's terminal and live editing silently don't work even though
the IDE appears to load fine.

**Remember: the wildcard cert does not auto-renew.** Repeat this whole Stage
B before it expires (90 days from issuance) — check with
`sudo certbot certificates`.

**IMPORTANT — copy-paste this correctly.** If you're pasting these commands
from a chat/doc that itself uses an outer `cat <<'EOF' ... EOF` to *display*
a block, don't paste that outer wrapper — only what's inside it is meant to
run. Pasting the wrapper too just echoes the commands back as text without
executing them, and it's easy to not notice.

## Phase 8 — Backups

```bash
cd ~/cloud_workspace_zaid
sudo ~/cloud_workspace_zaid/infra/scripts/backup-platform-db.sh
sudo ~/cloud_workspace_zaid/infra/scripts/list-platform-backups.sh   # confirm it worked

(sudo crontab -l 2>/dev/null; echo "0 3 * * * $HOME/cloud_workspace_zaid/infra/scripts/backup-platform-db.sh >> $HOME/cloud_workspace_zaid/backup.log 2>&1") | sudo crontab -
sudo crontab -l   # confirm it saved
```

## Phase 9 — Final verification checklist

- [ ] `https://workspace.<domain>` loads, no cert warning
- [ ] `https://api.<domain>/health` returns `{"success":true}`
- [ ] Register a new account, log in
- [ ] Create a workspace, confirm status becomes `running`
- [ ] Open its IDE URL (`https://<slug>.workspace.<domain>`) — no cert warning, code-server loads
- [ ] Create a file in the IDE, stop the workspace, start it again, confirm the file is still there
- [ ] Take a snapshot, modify the file, stop the workspace, restore the snapshot, confirm it reverted
- [ ] Log in as a second account, confirm it cannot see or access the first account's workspace
- [ ] Delete the test workspace, confirm its container and volume are actually gone (`docker ps -a`, `docker volume ls`)

If all of these pass, the new server is a complete, working replacement.
