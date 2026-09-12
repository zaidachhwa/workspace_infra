FROM cloudworkspace/dev-node:latest

USER root

# MongoDB has not yet published server binaries for our base's OS release
# (Debian 13 "trixie") — only their bookworm (Debian 12) build is available.
# glibc is backward-compatible, so the bookworm binary runs fine on trixie;
# verified directly before committing to this (see conversation/testing notes).
RUN curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main" > /etc/apt/sources.list.d/mongodb-org-8.0.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends mongodb-org-server mongodb-mongosh \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER 1000
WORKDIR /home/coder/project
ENTRYPOINT ["/usr/local/bin/start.sh"]
