#!/usr/bin/env bash
#
# install-nodejs.sh - Install nvm and Node.js (LTS) for a user.
#
# nvm is installed per user, so this script prompts for the target username.
#
# Self-contained: download and run this script on its own.
# Usage (as root):  ./install-nodejs.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root (e.g. 'su -' first)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

NVM_VERSION="v0.40.3"   # nvm release used by this installer

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# run_as <user> <command...> - run a command as the given user
run_as() { local u="$1"; shift; runuser -u "$u" -- "$@"; }

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

pick_user "Node.js user" \
"Enter the username to install nvm and Node.js for.\n\nLeave EMPTY to skip (nvm is installed per user)."

APP_USER="$PICKED_USER"

if [ -z "$APP_USER" ]; then
  log "No username given - skipping nvm and Node.js installation"
  exit 0
fi

APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"

log "Updating package lists and installing prerequisites"
apt-get update
apt-get install -y curl ca-certificates git

NVM_DIR="$APP_HOME/.nvm"
touch "$APP_HOME/.bashrc"
chown "$APP_USER":"$(id -gn "$APP_USER")" "$APP_HOME/.bashrc"

log "Installing nvm and Node.js (LTS) for $APP_USER"

# Official nvm installer; clones nvm to ~/.nvm and adds the loader to ~/.bashrc
run_as "$APP_USER" env HOME="$APP_HOME" PROFILE="$APP_HOME/.bashrc" \
  bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash"

# Install the latest LTS Node.js (this also provides npm and npx)
run_as "$APP_USER" env HOME="$APP_HOME" NVM_DIR="$NVM_DIR" bash -c '
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default "lts/*"
  echo "  nvm:  $(nvm --version)"
  for tool in node npm npx; do
    if command -v "$tool" >/dev/null 2>&1; then
      echo "  $tool: $("$tool" --version)"
    else
      echo "  WARNING: $tool not found after installation" >&2
    fi
  done
'

log "Done!"
echo "nvm and Node.js installed for '$APP_USER'. Open a new shell (or run 'source ~/.bashrc') to use them."
