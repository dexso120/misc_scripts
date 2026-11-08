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
# Leave the username empty to skip the sudo-group and SSH-key steps.
# After you pick applications, if Neovim/NvChad or Docker is selected,
# you are asked which user should receive the per-user setup
# (NvChad config, Nerd Font, docker group).

set -euo pipefail

#------------------------------------------------------------------------------
# Must be run as root
#------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "Error: this script must be run as root (e.g. 'su -' first)." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

NVM_VERSION="v0.40.3"   # nvm release used by the Node.js installer

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

# run_as <user> <command...> - run a command as the given user
run_as() { local u="$1"; shift; runuser -u "$u" -- "$@"; }

# pick_user <title> <message> [default]
# Prompts for a username via whiptail and sets PICKED_USER.
# Empty input = skip (PICKED_USER is empty). Offers to create unknown users.
pick_user() {
  local title="$1" msg="$2" default="${3:-}"
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

#------------------------------------------------------------------------------
# 1. Base packages, then ask which user to configure
#------------------------------------------------------------------------------
log "Updating package lists and installing base packages"
apt-get update
apt-get install -y sudo whiptail curl ca-certificates

pick_user "User setup" \
"Enter the username to add to the sudo group.\n\nLeave EMPTY to skip adding a user to sudo and creating an SSH key."
TARGET_USER="$PICKED_USER"

if [ -z "$TARGET_USER" ]; then
  log "No username entered - skipping sudo group and SSH key steps"
fi

TARGET_HOME=""
KEY_FILE=""
if [ -n "$TARGET_USER" ]; then
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

  log "Adding $TARGET_USER to the sudo group"
  usermod -aG sudo "$TARGET_USER"
else
  log "Skipping step 1 (sudo group) - no username given"
fi

#------------------------------------------------------------------------------
# 2. SSH server
#------------------------------------------------------------------------------
SSH_ENABLED=0
if whiptail --title "SSH server" --yesno \
  "Install and enable the SSH server?" 8 50; then
  log "Installing and enabling the SSH server"
  apt-get install -y openssh-server
  systemctl enable --now ssh
  SSH_ENABLED=1
else
  log "Skipping SSH server installation"
fi

#------------------------------------------------------------------------------
# 3. SSH key for the user
#------------------------------------------------------------------------------
if [ -z "$TARGET_USER" ]; then
  log "Skipping step 3 (SSH key) - no username given"
else
  KEY_FILE="$TARGET_HOME/.ssh/id_ed25519"
  if [ -f "$KEY_FILE" ]; then
    log "SSH key already exists at $KEY_FILE - skipping"
  else
    log "Creating SSH key for $TARGET_USER"
    run_as "$TARGET_USER" mkdir -p "$TARGET_HOME/.ssh"
    chmod 700 "$TARGET_HOME/.ssh"
    run_as "$TARGET_USER" ssh-keygen -t ed25519 -N "" -C "${TARGET_USER}@$(hostname)" -f "$KEY_FILE"
  fi
fi

#------------------------------------------------------------------------------
# 4. Application selection (whiptail)
#------------------------------------------------------------------------------
if ! CHOICES=$(whiptail --title "Application Installer" \
  --separate-output \
  --checklist "Select applications to install\n(SPACE to toggle, ENTER to confirm):" \
  21 70 7 \
  "all"    "Install ALL applications below" OFF \
  "nvim"   "Neovim + NvChad"                OFF \
  "vim"    "Vim editor"                     OFF \
  "git"    "Git version control"            OFF \
  "golang" "Go programming language"        OFF \
  "docker" "Docker Engine"                  OFF \
  "nodejs" "Node.js via nvm (+ npm, npx)"     OFF \
  3>&1 1>&2 2>&3); then
  echo "Selection cancelled - skipping application installs."
  CHOICES=""
fi

declare -A WANT=()
while IFS= read -r item; do
  [ -n "$item" ] && WANT["$item"]=1
done <<< "$CHOICES"

if [ -n "${WANT[all]:-}" ]; then
  for app in nvim vim git golang docker nodejs; do WANT["$app"]=1; done
fi

#------------------------------------------------------------------------------
# Which user gets the per-user setup? (asked only when it is needed)
#------------------------------------------------------------------------------
APP_USER=""
APP_HOME=""
if [ -n "${WANT[nvim]:-}" ] || [ -n "${WANT[docker]:-}" ] || [ -n "${WANT[nodejs]:-}" ]; then
  pick_user "Application user" \
"Enter the username to install the selected applications for:\n  - NvChad config + Nerd Font (Neovim)\n  - docker group membership (Docker)\n  - nvm + Node.js, npm, npx (Node.js)\n\nLeave EMPTY to skip these per-user parts." \
    "$TARGET_USER"
  APP_USER="$PICKED_USER"
  if [ -n "$APP_USER" ]; then
    APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
  else
    log "No application user given - skipping NvChad/Nerd Font, docker group and nvm/Node.js"
  fi
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

install_nodejs() {
  log "Installing nvm and Node.js (LTS)"

  if [ -z "$APP_USER" ]; then
    echo "nvm is installed per user and no user was given - skipping Node.js."
    return 0
  fi

  apt-get install -y curl ca-certificates git

  NVM_DIR="$APP_HOME/.nvm"
  touch "$APP_HOME/.bashrc"
  chown "$APP_USER":"$(id -gn "$APP_USER")" "$APP_HOME/.bashrc"

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

  echo "nvm and Node.js installed for '$APP_USER'. Open a new shell (or run 'source ~/.bashrc') to use them."
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

  if [ -z "$APP_USER" ]; then
    echo "Neovim installed. No user given - skipping NvChad config and Nerd Font."
    return 0
  fi

  # NvChad starter config
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

  echo "NvChad installed for user '$APP_USER'. Run 'nvim' once to let it download plugins."
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
  if [ -n "$APP_USER" ]; then
    usermod -aG docker "$APP_USER"
  else
    echo "No user given - not adding anyone to the 'docker' group."
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
[ -n "${WANT[nodejs]:-}" ] && install_nodejs

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
log "All done!"
if [ "$SSH_ENABLED" -eq 1 ]; then
  echo "  - SSH server running (systemctl status ssh)"
else
  echo "  - SSH server not installed"
fi
if [ -n "$TARGET_USER" ]; then
  echo "  - $TARGET_USER added to the 'sudo' group"
  echo "  - SSH public key: ${KEY_FILE}.pub"
  echo
  cat "${KEY_FILE}.pub" 2>/dev/null || true
  echo
else
  echo "  - No sudo user given: sudo group and SSH key steps were skipped"
fi
if [ -n "$APP_USER" ]; then
  [ -n "${WANT[nvim]:-}" ]   && echo "  - NvChad + Nerd Font installed for $APP_USER"
  [ -n "${WANT[docker]:-}" ] && echo "  - $APP_USER added to the 'docker' group"
  [ -n "${WANT[nodejs]:-}" ]  && echo "  - nvm + Node.js LTS (npm, npx) installed for $APP_USER"
fi
if [ -n "$TARGET_USER" ] || [ -n "$APP_USER" ]; then
  echo
  echo "NOTE: Log out and back in (or reboot) for new group memberships"
  echo "      (sudo, docker) to take effect."
fi
