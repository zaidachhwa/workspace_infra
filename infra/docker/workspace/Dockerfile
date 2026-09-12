FROM codercom/code-server:latest

USER root
# "General Purpose" template: Node + Python + build tools, so most people
# never need to think about which template to pick. Full Stack extends this
# same image (see ../workspace-fullstack/Dockerfile), so it gets Python too.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl gnupg git \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs python3 python3-pip python3-venv build-essential \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /home/coder/project \
  && chown -R 1000:1000 /home/coder/project

# WORKDIR ignores the active USER when it creates a directory, so the project
# dir must already exist (and be chowned) above — otherwise a fresh named
# volume mounted here inherits root ownership and code-server can't write to it.
USER 1000
WORKDIR /home/coder/project
