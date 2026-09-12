FROM codercom/code-server:latest

USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl gnupg git \
  && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /home/coder/project \
  && chown -R 1000:1000 /home/coder/project

# WORKDIR ignores the active USER when it creates a directory, so the project
# dir must already exist (and be chowned) above — otherwise a fresh named
# volume mounted here inherits root ownership and code-server can't write to it.
USER 1000
WORKDIR /home/coder/project
