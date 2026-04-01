#!/bin/bash
set -eux -o pipefail

AGENT_USER="agent"
DEV_GROUP="devvm"

dnf install -y git curl sudo ca-certificates chezmoi zsh zsh-autosuggestions tmux ripgrep fd-find bat eza zoxide fzf jq tar unzip gzip make gcc gcc-c++ helm acl

if ! getent group "$DEV_GROUP" >/dev/null 2>&1; then
	groupadd -f "$DEV_GROUP"
fi

usermod -a -G "$DEV_GROUP" dev
usermod -s /bin/zsh dev

if ! id "$AGENT_USER" >/dev/null 2>&1; then
	useradd -m -s /bin/bash -G "$DEV_GROUP" "$AGENT_USER"
else
	usermod -a -G "$DEV_GROUP" "$AGENT_USER"
fi

usermod -s /bin/zsh "$AGENT_USER"

install -d -m 2775 -o root -g "$DEV_GROUP" /workspaces
setfacl -m "g:${DEV_GROUP}:rwx" /workspaces
setfacl -d -m "g:${DEV_GROUP}:rwx" /workspaces

if ! command -v mise >/dev/null 2>&1; then
	if dnf copr enable -y jdxcode/mise; then
		dnf install -y mise
	else
		curl https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh
	fi
fi
