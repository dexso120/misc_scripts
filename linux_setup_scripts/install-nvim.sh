#!/usr/bin/env bash
#
# install-nvim.sh - Install Neovim, plus the NvChad config and Nerd Font for a user.
#
# Neovim itself is installed system-wide. NvChad and the font are per user, so
# this script prompts for the target username (empty = Neovim only).
#
# Self-contained: download and run this script on its own.
# Usage (as root):  ./install-nvim.sh

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root (e.g. 'su -' first)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

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

pick_user "Neovim user" \
"Enter the username to install the NvChad config and Nerd Font for.\n\nLeave EMPTY to install Neovim only (system-wide)."

APP_USER="$PICKED_USER"
APP_HOME=""
if [ -n "$APP_USER" ]; then
  APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
fi

log "Installing Neovim"

# NvChad needs a recent Neovim; Debian's packaged version is too old,
# so grab the official release tarball.
apt-get update
apt-get install -y git curl tar build-essential ripgrep unzip fontconfig

case "$(uname -m)" in
  x86_64)  NVIM_PKG="nvim-linux-x86_64" ;;
  aarch64) NVIM_PKG="nvim-linux-arm64" ;;
  *) echo "Unsupported architecture for Neovim: $(uname -m)" >&2; exit 1 ;;
esac

TMP_TAR="$(mktemp)"
curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${NVIM_PKG}.tar.gz" -o "$TMP_TAR"
rm -rf /opt/nvim
mkdir -p /opt/nvim
tar -xzf "$TMP_TAR" -C /opt/nvim --strip-components=1
rm -f "$TMP_TAR"
ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

if [ -z "$APP_USER" ]; then
  log "Neovim installed. No user given - skipping NvChad config and Nerd Font."
  exit 0
fi

# NvChad starter config
log "Installing NvChad config for $APP_USER"
NVIM_CFG="$APP_HOME/.config/nvim"
if [ -d "$NVIM_CFG" ]; then
  BACKUP="${NVIM_CFG}.bak.$(date +%Y%m%d%H%M%S)"
  echo "Existing Neovim config found - backing up to $BACKUP"
  mv "$NVIM_CFG" "$BACKUP"
fi
run_as "$APP_USER" mkdir -p "$APP_HOME/.config"
run_as "$APP_USER" git clone --depth 1 https://github.com/NvChad/starter "$NVIM_CFG"
rm -rf "$NVIM_CFG/.git"

# Nerd Font (0xProto) for NvChad icons
log "Installing 0xProto Nerd Font"
FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/0xProto.zip"
FONT_DIR="$APP_HOME/.local/share/fonts/0xProto"
TMP_ZIP="$(mktemp --suffix=.zip)"

curl -fsSL "$FONT_URL" -o "$TMP_ZIP"
run_as "$APP_USER" mkdir -p "$FONT_DIR"
unzip -o -q "$TMP_ZIP" -d "$FONT_DIR"
rm -f "$TMP_ZIP"
chown -R "$APP_USER":"$(id -gn "$APP_USER")" "$APP_HOME/.local"
run_as "$APP_USER" fc-cache -f "$FONT_DIR"

log "Done!"
echo "NvChad installed for user '$APP_USER'. Run 'nvim' once to let it download plugins."
echo "Font installed to $FONT_DIR."
echo "Set your terminal's font to '0xProto Nerd Font' (on the machine whose"
echo "terminal you use - e.g. your SSH client's computer, if you connect remotely)."
