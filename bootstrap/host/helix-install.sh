#!/usr/bin/env bash
set -euo pipefail

install_only=false

for arg in "$@"; do
	case "$arg" in
	--install-only)
		install_only=true
		;;
	*)
		echo "Error: unknown argument '$arg'." >&2
		exit 1
		;;
	esac
done

if ! command -v cargo >/dev/null 2>&1; then
	echo "Error: cargo is required to build Helix from source. Run 'mise install' first." >&2
	exit 1
fi

if ! command -v git >/dev/null 2>&1; then
	echo "Error: git is required to build Helix from source." >&2
	exit 1
fi

helix_source_dir="${XDG_DATA_HOME:-$HOME/.local/share}/src/helix"
helix_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/helix"
helix_runtime_link="$helix_config_dir/runtime"

mkdir -p "$(dirname "$helix_source_dir")" "$helix_config_dir"

if [[ ! -d "$helix_source_dir/.git" ]]; then
	git clone --depth 1 https://github.com/helix-editor/helix "$helix_source_dir"
elif [[ "$install_only" == false ]]; then
	if [[ -n "$(git -C "$helix_source_dir" status --porcelain)" ]]; then
		echo "Warning: Helix source tree has local changes; skipping git pull in '$helix_source_dir'." >&2
	else
		git -C "$helix_source_dir" pull --ff-only
	fi
fi

(
	cd "$helix_source_dir"
	cargo install --path helix-term --locked --root "$HOME/.local"
)

if [[ -L "$helix_runtime_link" || ! -e "$helix_runtime_link" ]]; then
	ln -sfn "$helix_source_dir/runtime" "$helix_runtime_link"
else
	echo "Warning: leaving existing Helix runtime at $helix_runtime_link in place" >&2
fi
