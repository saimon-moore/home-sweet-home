#!/usr/bin/env bash
set -euo pipefail

if ! command -v limactl >/dev/null 2>&1; then
	echo "Error: limactl is required but was not found on PATH." >&2
	exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

INSTANCE_NAME="dev"
TARGET=""
CONTEXT="work"
REPO_PATH="/workspaces/home-sweet-home"
REPO_URL=""
NAME=""
EMAIL=""
GITHUB_USERNAME=""
WORK_USERNAME=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--vm-name)
		INSTANCE_NAME="$2"
		shift 2
		;;
	--target)
		TARGET="$2"
		shift 2
		;;
	--context)
		CONTEXT="$2"
		shift 2
		;;
	--repo-path)
		REPO_PATH="$2"
		shift 2
		;;
	--repo-url)
		REPO_URL="$2"
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
	-h | --help)
		echo "Usage: bootstrap/vm/apply-user.sh --target {dev|agent} [--vm-name NAME] [--context work] [--repo-path DIR] [--repo-url URL] [--name NAME] [--email EMAIL] [--github-username USERNAME] [--work-username USERNAME]"
		exit 0
		;;
	*)
		echo "Error: unknown argument '$1'." >&2
		exit 1
		;;
	esac
done

if [[ "$TARGET" != "dev" && "$TARGET" != "agent" ]]; then
	echo "Error: --target must be one of: dev, agent." >&2
	exit 1
fi

if [[ "$CONTEXT" != "work" ]]; then
	echo "Error: only context=work is implemented right now." >&2
	exit 1
fi

if [[ -z "$REPO_URL" ]]; then
	if ! command -v git >/dev/null 2>&1; then
		echo "Error: git is required to derive the VM clone URL from this checkout." >&2
		exit 1
	fi

	REPO_URL="$(git -C "$REPO_ROOT" config --get remote.origin.url || true)"
	if [[ -z "$REPO_URL" ]]; then
		echo "Error: could not determine remote.origin.url from this checkout. Pass --repo-url explicitly." >&2
		exit 1
	fi

	case "$REPO_URL" in
	git@github.com:*)
		REPO_URL="https://github.com/${REPO_URL#git@github.com:}"
		;;
	ssh://git@github.com/*)
		REPO_URL="https://github.com/${REPO_URL#ssh://git@github.com/}"
		;;
	esac
fi

APPLY_ARGS=(./bootstrap/apply-chezmoi.sh --target "$TARGET" --context "$CONTEXT")

if [[ -n "$NAME" ]]; then
	APPLY_ARGS+=(--name "$NAME")
fi

if [[ -n "$EMAIL" ]]; then
	APPLY_ARGS+=(--email "$EMAIL")
fi

if [[ -n "$GITHUB_USERNAME" ]]; then
	APPLY_ARGS+=(--github-username "$GITHUB_USERNAME")
fi

if [[ -n "$WORK_USERNAME" ]]; then
	APPLY_ARGS+=(--work-username "$WORK_USERNAME")
fi

limactl shell --workdir /home/dev "$INSTANCE_NAME" bash -lc "sudo rpm -q zsh-autosuggestions >/dev/null 2>&1 || sudo dnf install -y zsh-autosuggestions"
limactl shell --workdir /home/dev "$INSTANCE_NAME" bash -lc "command -v ssh-keygen >/dev/null 2>&1 || sudo dnf install -y openssh-clients"
limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu "$TARGET" bash -lc "mkdir -p \"\$HOME/.ssh\" && chmod 700 \"\$HOME/.ssh\" && if [[ ! -f \"\$HOME/.ssh/id_ed25519\" ]]; then ssh-keygen -q -t ed25519 -N '' -C \"$TARGET@$INSTANCE_NAME\" -f \"\$HOME/.ssh/id_ed25519\"; fi && chmod 600 \"\$HOME/.ssh/id_ed25519\" && chmod 644 \"\$HOME/.ssh/id_ed25519.pub\""

printf -v REPO_PATH_Q '%q' "$REPO_PATH"
printf -v REPO_PARENT_Q '%q' "$(dirname "$REPO_PATH")"
printf -v REPO_URL_Q '%q' "$REPO_URL"
printf -v APPLY_CMD '%q ' "${APPLY_ARGS[@]}"

repo_status=0
limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu dev bash -lc "if [[ -d $REPO_PATH_Q/.git && -f $REPO_PATH_Q/bootstrap/apply-chezmoi.sh ]]; then exit 0; fi; if [[ -e $REPO_PATH_Q ]]; then echo 'Error: repo path exists in VM but does not look like a home-sweet-home git checkout: $REPO_PATH' >&2; exit 1; fi; exit 2" || repo_status=$?

if [[ $repo_status -eq 2 ]]; then
	limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu dev bash -lc "mkdir -p $REPO_PARENT_Q && git clone $REPO_URL_Q $REPO_PATH_Q && chgrp -R devvm $REPO_PATH_Q && chmod -R g+rwX $REPO_PATH_Q && find $REPO_PATH_Q -type d -exec chmod g+s {} +"
elif [[ $repo_status -eq 0 ]]; then
	limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu dev bash -lc "git -C $REPO_PATH_Q pull --ff-only"
elif [[ $repo_status -ne 0 ]]; then
	exit "$repo_status"
fi

limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu dev bash -lc 'origin_url="$(git -C '"$REPO_PATH_Q"' remote get-url origin 2>/dev/null || true)"; case "$origin_url" in https://github.com/*) git -C '"$REPO_PATH_Q"' remote set-url origin "git@github.com:${origin_url#https://github.com/}" ;; https://source.xing.com/*) git -C '"$REPO_PATH_Q"' remote set-url origin "git@source.xing.com:${origin_url#https://source.xing.com/}" ;; esac'

exec limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu "$TARGET" bash -lc "cd $REPO_PATH_Q; $APPLY_CMD"
