#!/usr/bin/env bash
###############################################################################
# docker_install.sh
# Install Docker Engine + Compose on Ubuntu from Docker's official apt repo.
# Supports Ubuntu 22.04, 24.04, 25.10, 26.04 (64-bit).
# https://github.com/proars/Docker-Install-Ubuntu-Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/proars/Docker-Install-Ubuntu-Script/main/docker_install.sh -o docker_install.sh
#   less docker_install.sh          # read it first
#   sudo bash docker_install.sh
#
# Options (environment variables):
#   ADD_USER=1   add the user who ran sudo to the docker group (root-equivalent!)
#   SKIP_TEST=1  don't run the hello-world container at the end
#   FORCE=1      continue on an Ubuntu release this script doesn't know about
###############################################################################
set -euo pipefail

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"

# --- 1. Check the OS --------------------------------------------------------
[[ -r /etc/os-release ]] || die "/etc/os-release not found. Is this Ubuntu?"
# shellcheck source=/dev/null
. /etc/os-release
[[ ${ID:-} == "ubuntu" ]] || die "This script is for Ubuntu (found: ${ID:-unknown}). Mint/Pop!_OS are not officially supported by Docker."

CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
[[ -n $CODENAME ]] || die "Could not detect the Ubuntu codename."

case "$CODENAME" in
  jammy|noble|questing|resolute) ;;
  *)
    if [[ ${FORCE:-0} == 1 ]]; then
      warn "Ubuntu '$CODENAME' is not in this script's tested list. Continuing because FORCE=1."
    else
      die "Ubuntu '$CODENAME' is not in this script's tested list. Check https://docs.docker.com/engine/install/ubuntu/ and rerun with FORCE=1 if Docker supports it."
    fi
    ;;
esac

ARCH="$(dpkg --print-architecture)"
log "Ubuntu ${VERSION_ID:-?} ($CODENAME), architecture $ARCH"

export DEBIAN_FRONTEND=noninteractive

# --- 2. Remove conflicting packages ----------------------------------------
log "Removing conflicting packages (docker.io, podman-docker, old containerd/runc) if present"
CONFLICTS=(docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc)
mapfile -t INSTALLED < <(dpkg-query -W -f='${Package} ${Status}\n' "${CONFLICTS[@]}" 2>/dev/null \
  | awk '$NF == "installed" {print $1}')
if (( ${#INSTALLED[@]} )); then
  apt-get remove -y "${INSTALLED[@]}"
else
  echo "None found."
fi

# --- 3. Clean up files left by the old version of this script --------------
# The 2022/2023 script wrote docker.list + docker.gpg. Leaving them next to the
# new docker.sources makes apt fail with "Conflicting values set for option Signed-By".
for f in /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.gpg; do
  if [[ -e $f ]]; then
    log "Removing old file $f"
    rm -f "$f"
  fi
done

# --- 4. Add Docker's GPG key and apt repository ----------------------------
log "Adding Docker's GPG key and apt repository"
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update

# --- 5. Install Docker Engine, CLI, containerd, Buildx, Compose ------------
log "Installing Docker Engine, Buildx and Compose"
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 6. Start on boot -------------------------------------------------------
log "Enabling docker and containerd on boot"
systemctl enable --now containerd.service docker.service

# --- 7. Optional: docker group ---------------------------------------------
TARGET_USER="${SUDO_USER:-}"
if [[ ${ADD_USER:-0} == 1 ]]; then
  if [[ -n $TARGET_USER && $TARGET_USER != "root" ]]; then
    log "Adding $TARGET_USER to the docker group"
    warn "Members of the docker group are effectively root on this machine."
    groupadd -f docker
    usermod -aG docker "$TARGET_USER"
    echo "Log out and back in (or run 'newgrp docker') for it to apply."
  else
    warn "ADD_USER=1 but no non-root sudo user detected. Skipping."
  fi
fi

# --- 8. Verify --------------------------------------------------------------
log "Installed versions"
docker --version
docker compose version
docker buildx version

if [[ ${SKIP_TEST:-0} != 1 ]]; then
  log "Running hello-world test container"
  docker run --rm hello-world
fi

log "Done. Docker is installed and running."
cat <<'NOTE'

Two things worth knowing:
  * Ports you publish with -p bypass ufw. Bind admin UIs to 127.0.0.1
    (e.g. -p 127.0.0.1:9000:9000) or put them behind a reverse proxy.
  * Upgrade later with: sudo apt update && sudo apt upgrade
NOTE
