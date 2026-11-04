#!/usr/bin/env bash
#
# setup-debian.sh - Bootstrap a fresh Debian machine
#
#   1. Adds a user (you choose) to the sudo group
#   2. Installs and enables the SSH server
#   3. Creates an SSH key for that user
#   4. Lets you pick applications to install via whiptail
#
# Usage (as root):  ./setup-debian.sh
# The script asks which user should be added to the sudo group.
# Leave the username empty to skip all user-specific steps.

set -euo pipefail

#------------------------------------------------------------------------------
# Must be run as root
#------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root (e.g. 'su -' first)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

run_as_user() { runuser -u "$TARGET_USER" -- "$@"; }

#------------------------------------------------------------------------------
# 1. Base packages, then ask which user to configure
#------------------------------------------------------------------------------
log "Updating package lists and installing base packages"
apt-get update
apt-get install -y sudo whiptail curl ca-certificates

while true; do
  if ! TARGET_USER=$(whiptail --title "User setup" \
    --inputbox "Enter the username to add to the sudo group.\n\nLeave EMPTY to skip (no user will be configured)." 12 64 \
    3>&1 1>&2 2>&3); then
    echo "Cancelled."
    exit 1
  fi

  # Empty input = skip all user-specific steps
  if [ -z "$TARGET_USER" ]; then
    log "No username entered - skipping sudo, SSH key and per-user setup"
    break
  fi

  if [ "$TARGET_USER" = "root" ]; then
    whiptail --msgbox "Please enter a non-root username (or leave empty to skip)." 8 60
    continue
  fi

  if id "$TARGET_USER" >/dev/null 2>&1; then
    break
  fi

  if whiptail --yesno "User '$TARGET_USER' does not exist. Create it now?" 10 60; then
    adduser --gecos "" "$TARGET_USER"   # prompts for a password
    break
  fi
done

TARGET_HOME=""
KEY_FILE=""
if [ -n "$TARGET_USER" ]; then
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

  log "Adding $TARGET_USER to the sudo group"
  usermod -aG sudo "$TARGET_USER"
fi

#------------------------------------------------------------------------------
# 2. SSH server
#------------------------------------------------------------------------------
log "Installing and enabling the SSH server"
apt-get install -y openssh-server
systemctl enable --now ssh

#------------------------------------------------------------------------------
# 3. SSH key for the user
#------------------------------------------------------------------------------
if [ -z "$TARGET_USER" ]; then
  log "No user selected - skipping SSH key creation"
else
  KEY_FILE="$TARGET_HOME/.ssh/id_ed25519"
  if [ -f "$KEY_FILE" ]; then
    log "SSH key already exists at $KEY_FILE - skipping"
  else
    log "Creating SSH key for $TARGET_USER"
    run_as_user mkdir -p "$TARGET_HOME/.ssh"
    chmod 700 "$TARGET_HOME/.ssh"
    run_as_user ssh-keygen -t ed25519 -N "" -C "${TARGET_USER}@$(hostname)" -f "$KEY_FILE"
  fi
fi

#------------------------------------------------------------------------------
# 4. Application selection (whiptail)
#------------------------------------------------------------------------------
if ! CHOICES=$(whiptail --title "Application Installer" \
  --separate-output \
  --checklist "Select applications to install\n(SPACE to toggle, ENTER to confirm):" \
  20 70 6 \
  "all"    "Install ALL applications below" OFF \
  "nvim"   "Neovim + NvChad"                OFF \
  "vim"    "Vim editor"                     OFF \
  "git"    "Git version control"            OFF \
  "golang" "Go programming language"        OFF \
  "docker" "Docker Engine"                  OFF \
  3>&1 1>&2 2>&3); then
  echo "Selection cancelled - skipping application installs."
  CHOICES=""
fi

declare -A WANT=()
while IFS= read -r item; do
  [ -n "$item" ] && WANT["$item"]=1
done <<< "$CHOICES"

if [ -n "${WANT[all]:-}" ]; then
  for app in nvim vim git golang docker; do WANT["$app"]=1; done
fi

#------------------------------------------------------------------------------
# Installer functions
#------------------------------------------------------------------------------
install_git() {
  log "Installing Git"
  apt-get install -y git
}

install_vim() {
  log "Installing Vim"
  apt-get install -y vim
}

install_golang() {
  log "Installing Go"
  apt-get install -y golang-go
}

install_nvim() {
  log "Installing Neovim and NvChad"

  # NvChad needs a recent Neovim; Debian's packaged version is too old,
  # so grab the official release tarball.
  apt-get install -y git curl tar build-essential ripgrep unzip fontconfig

  case "$(uname -m)" in
    x86_64)  NVIM_PKG="nvim-linux-x86_64" ;;
    aarch64) NVIM_PKG="nvim-linux-arm64" ;;
    *) echo "Unsupported architecture for Neovim: $(uname -m)" >&2; return 1 ;;
  esac

  TMP_TAR="$(mktemp)"
  curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/${NVIM_PKG}.tar.gz" -o "$TMP_TAR"
  rm -rf /opt/nvim
  mkdir -p /opt/nvim
  tar -xzf "$TMP_TAR" -C /opt/nvim --strip-components=1
  rm -f "$TMP_TAR"
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

  if [ -z "$TARGET_USER" ]; then
    echo "Neovim installed. No user selected - skipping NvChad config and Nerd Font."
    return 0
  fi

  # NvChad starter config
  NVIM_CFG="$TARGET_HOME/.config/nvim"
  if [ -d "$NVIM_CFG" ]; then
    BACKUP="${NVIM_CFG}.bak.$(date +%Y%m%d%H%M%S)"
    echo "Existing Neovim config found - backing up to $BACKUP"
    mv "$NVIM_CFG" "$BACKUP"
  fi
  run_as_user mkdir -p "$TARGET_HOME/.config"
  run_as_user git clone --depth 1 https://github.com/NvChad/starter "$NVIM_CFG"
  rm -rf "$NVIM_CFG/.git"

  # Nerd Font (0xProto) for NvChad icons
  log "Installing 0xProto Nerd Font"
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.5.1/0xProto.zip"
  FONT_DIR="$TARGET_HOME/.local/share/fonts/0xProto"
  TMP_ZIP="$(mktemp --suffix=.zip)"

  curl -fsSL "$FONT_URL" -o "$TMP_ZIP"
  run_as_user mkdir -p "$FONT_DIR"
  unzip -o -q "$TMP_ZIP" -d "$FONT_DIR"
  rm -f "$TMP_ZIP"
  chown -R "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.local"
  run_as_user fc-cache -f "$FONT_DIR"

  echo "NvChad installed. Run 'nvim' once to let it download plugins."
  echo "Font installed to $FONT_DIR."
  echo "Set your terminal's font to '0xProto Nerd Font' (on the machine whose"
  echo "terminal you use - e.g. your SSH client's computer, if you connect remotely)."
}

install_docker() {
  log "Installing Docker Engine"
  # shellcheck disable=SC1091
  . /etc/os-release

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
  if [ -n "$TARGET_USER" ]; then
    usermod -aG docker "$TARGET_USER"
  else
    echo "No user selected - not adding anyone to the 'docker' group."
  fi
}

#------------------------------------------------------------------------------
# Run selected installs (git first, since nvim/others may rely on it)
#------------------------------------------------------------------------------
[ -n "${WANT[git]:-}"    ] && install_git
[ -n "${WANT[vim]:-}"    ] && install_vim
[ -n "${WANT[golang]:-}" ] && install_golang
[ -n "${WANT[nvim]:-}"   ] && install_nvim
[ -n "${WANT[docker]:-}" ] && install_docker

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
log "All done!"
echo "  - SSH server running (systemctl status ssh)"
if [ -n "$TARGET_USER" ]; then
  echo "  - $TARGET_USER added to the 'sudo' group"
  echo "  - SSH public key: ${KEY_FILE}.pub"
  echo
  cat "${KEY_FILE}.pub" 2>/dev/null || true
  echo
  echo "NOTE: Log out and back in (or reboot) for the new group memberships"
  echo "      (sudo, docker) to take effect."
else
  echo "  - No user was configured (no sudo group, SSH key, NvChad or docker group changes)"
fi
