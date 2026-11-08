#!/usr/bin/env bash
#
# install-docker.sh - Install Docker Engine, optionally adding a user to the
# 'docker' group.
#
# Self-contained: download and run this script on its own.
# Usage (as root):  ./install-docker.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root (e.g. 'su -' first)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# pick_user <title> <message> [default]
# Prompts for a username via whiptail and sets PICKED_USER.
# Empty input = skip (PICKED_USER is empty). Offers to create unknown users.
pick_user() {
  local title="$1" msg="$2" default="${3:-}"
  if ! command -v whiptail >/dev/null 2>&1; then
    apt-get update
    apt-get install -y whiptail
  fi
  while true; do
    if ! PICKED_USER=$(whiptail --title "$title" --inputbox "$msg" 12 66 "$default" \
      3>&1 1>&2 2>&3); then
      echo "Cancelled."
      exit 1
    fi

    [ -z "$PICKED_USER" ] && return 0

    if [ "$PICKED_USER" = "root" ]; then
      whiptail --msgbox "Please enter a non-root username (or leave empty to skip)." 8 60
      continue
    fi

    id "$PICKED_USER" >/dev/null 2>&1 && return 0

    if whiptail --yesno "User '$PICKED_USER' does not exist. Create it now?" 10 60; then
      adduser --gecos "" "$PICKED_USER"   # prompts for a password
      return 0
    fi
  done
}

pick_user "Docker user" \
"Enter the username to add to the 'docker' group.\n\nLeave EMPTY to skip adding a user."

APP_USER="$PICKED_USER"

log "Installing Docker Engine"
# shellcheck disable=SC1091
. /etc/os-release

apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

systemctl enable --now docker

log "Done!"
if [ -n "$APP_USER" ]; then
  usermod -aG docker "$APP_USER"
  echo "Added '$APP_USER' to the 'docker' group."
else
  echo "No user given - not adding anyone to the 'docker' group."
fi
if [ -n "$APP_USER" ]; then
  echo
  echo "NOTE: Log out and back in (or reboot) for the new 'docker' group membership to take effect."
fi
