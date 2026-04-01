#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_ROOT/chezmoi"
CONFIG_TEMPLATE="$SOURCE_DIR/.chezmoi.toml.tmpl"
TARGET=""
CONTEXT=""
DEST_DIR="$HOME"
NAME=""
EMAIL=""
GITHUB_USERNAME=""
WORK_USERNAME=""
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi"
CONFIG_FILE=""
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi"
STATE_FILE=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--target)
		TARGET="$2"
		shift 2
		;;
	--context)
		CONTEXT="$2"
		shift 2
		;;
	--destination)
		DEST_DIR="$2"
		shift 2
		;;
	--name)
		NAME="$2"
		shift 2
		;;
	--email)
		EMAIL="$2"
		shift 2
		;;
	--github-username)
		GITHUB_USERNAME="$2"
		shift 2
		;;
	--work-username)
		WORK_USERNAME="$2"
		shift 2
		;;
	--config-file)
		CONFIG_FILE="$2"
		shift 2
		;;
	--state-file)
		STATE_FILE="$2"
		shift 2
		;;
	-h | --help)
		echo "Usage: bootstrap/apply-chezmoi.sh --target {host|dev|agent} --context {work|private} [--destination DIR] [--name NAME] [--email EMAIL] [--github-username USERNAME] [--work-username USERNAME] [--config-file FILE] [--state-file FILE]"
		exit 0
		;;
	*)
		echo "Error: unknown argument '$1'." >&2
		exit 1
		;;
	esac
done

if ! command -v chezmoi >/dev/null 2>&1; then
	echo "Error: chezmoi is required but was not found on PATH." >&2
	exit 1
fi

if [[ -z "$TARGET" || -z "$CONTEXT" ]]; then
	echo "Error: --target and --context are required." >&2
	exit 1
fi

if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
	echo "Error: chezmoi config template not found: $CONFIG_TEMPLATE" >&2
	exit 1
fi

if [[ -z "$CONFIG_FILE" ]]; then
	CONFIG_FILE="$CONFIG_DIR/home-sweet-home-$TARGET-$CONTEXT.toml"
fi

if [[ -z "$STATE_FILE" ]]; then
	STATE_FILE="$STATE_DIR/chezmoistate.boltdb"
fi

mkdir -p "$(dirname "$CONFIG_FILE")" "$(dirname "$STATE_FILE")"

INIT_ARGS=(
	init
	--source "$SOURCE_DIR"
	--config-path "$CONFIG_FILE"
	--destination "$DEST_DIR"
	--promptString "Target=$TARGET"
	--promptString "Context=$CONTEXT"
)

if [[ -n "$NAME" ]]; then
	INIT_ARGS+=(--promptString "Git author name=$NAME")
fi

if [[ -n "$EMAIL" ]]; then
	INIT_ARGS+=(--promptString "Git author email=$EMAIL")
fi

if [[ -n "$GITHUB_USERNAME" ]]; then
	INIT_ARGS+=(--promptString "GitHub username=$GITHUB_USERNAME")
fi

if [[ "$CONTEXT" == "work" && -n "$WORK_USERNAME" ]]; then
	INIT_ARGS+=(--promptString "Work username=$WORK_USERNAME")
fi

if [[ ! -f "$CONFIG_FILE" ]] ||
	grep -Fq 'target = "Target"' "$CONFIG_FILE" ||
	grep -Fq 'context = "Context"' "$CONFIG_FILE" ||
	grep -Fq 'name = "Git author name"' "$CONFIG_FILE" ||
	grep -Fq 'email = "Git author email"' "$CONFIG_FILE" ||
	grep -Fq 'github_username = "GitHub username"' "$CONFIG_FILE" ||
	grep -Fq 'work_username = "Work username"' "$CONFIG_FILE"; then
	chezmoi "${INIT_ARGS[@]}"
fi

if ! grep -Fq 'configFileTemplateHasChanged = false' "$CONFIG_FILE"; then
	printf '\n[warnings]\nconfigFileTemplateHasChanged = false\n' >>"$CONFIG_FILE"
fi

chezmoi \
	--config "$CONFIG_FILE" \
	--destination "$DEST_DIR" \
	--persistent-state "$STATE_FILE" \
	--source "$SOURCE_DIR" \
	apply

if [[ "$DEST_DIR" == "$HOME" && -f "$HOME/.config/mise/config.toml" ]] && command -v mise >/dev/null 2>&1; then
	(
		cd "$HOME"
		mise trust "$HOME/.config/mise/config.toml"
		mise install
	)
fi

if [[ "$DEST_DIR" == "$HOME" && "$TARGET" == "dev" && "$CONTEXT" == "work" ]] && command -v mise >/dev/null 2>&1; then
	(
		cd "$HOME"
		if mise exec -- sh -lc 'command -v helm_ls >/dev/null 2>&1' && [[ ! -e "$HOME/.local/bin/helm-ls" ]]; then
			mkdir -p "$HOME/.local/bin"
			ln -s "$(mise exec -- sh -lc 'command -v helm_ls')" "$HOME/.local/bin/helm-ls"
		fi
		COURSIER_INSTALL_DIR="$HOME/.local/bin" mise exec -- cs install --install-dir "$HOME/.local/bin" metals
	)
fi
