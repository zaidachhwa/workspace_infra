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

# Common baseline editor setup for every workspace — starting point, not a
# lock: anyone can still change their own settings or add more extensions
# afterward within that workspace. code-server can only use Open VSX (not
# Microsoft's Marketplace — their terms restrict it to Microsoft-branded
# builds), so this list is exactly what was verified to actually be there;
# ms-python.vscode-pylance is Microsoft-marketplace-only and was left out
# because it isn't on Open VSX at all — ms-python.python is the fallback.
RUN code-server \
  --install-extension esbenp.prettier-vscode \
  --install-extension ms-python.python \
  --install-extension ms-python.debugpy \
  --install-extension ms-python.vscode-python-envs \
  --install-extension wallabyjs.quokka-vscode \
  --install-extension bradlc.vscode-tailwindcss \
  --install-extension rangav.vscode-thunder-client \
  --install-extension anthropic.claude-code \
  --install-extension naumovs.color-highlight \
  --install-extension ms-azuretools.vscode-containers \
  --install-extension catppuccin.catppuccin-vsc \
  --install-extension prisma.prisma \
  --install-extension pkief.material-icon-theme \
  --install-extension ritwickdey.liveserver \
  --install-extension formulahendry.auto-close-tag

COPY --chown=1000:1000 settings.json /home/coder/.local/share/code-server/User/settings.json
