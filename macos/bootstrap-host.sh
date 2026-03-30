#!/usr/bin/env bash
set -euo pipefail

# One-time host bootstrap for convenient Lima aliases and optional shared mounts.
# Run on macOS host (not inside the VM).

INSTANCE_NAME="dev"
SHARED_GUEST_DIR="/home/lima.guest/Code"
SHARED_HOST_DIR=""
ZSHRC="$HOME/.zshrc"
BLOCK_START="# >>> agentex aliases >>>"
BLOCK_END="# <<< agentex aliases <<<"

usage() {
	cat <<EOF
Usage: ./bootstrap-host.sh [--shared-dir /absolute/host/path]

Updates host aliases for the agent VM.

By default, no host directory is shared with the VM.
When --shared-dir is set, the directory is mounted inside the guest at
$SHARED_GUEST_DIR. If the "$INSTANCE_NAME" instance does not exist yet,
the script creates it with that mount. If it already exists, the script
updates the instance config and restarts it.
EOF
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--shared-dir)
			if [[ $# -lt 2 ]]; then
				echo "Error: --shared-dir requires a value." >&2
				exit 1
			fi
			SHARED_HOST_DIR="$2"
			shift 2
			;;
		--shared-dir=*)
			SHARED_HOST_DIR="${1#*=}"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "Error: unknown argument '$1'." >&2
			usage >&2
			exit 1
			;;
		esac
	done
}

require_command() {
	local cmd="$1"
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Error: '$cmd' is required but was not found on PATH." >&2
		exit 1
	fi
}

validate_shared_dir() {
	if [[ -z "$SHARED_HOST_DIR" ]]; then
		return
	fi

	if [[ "$SHARED_HOST_DIR" != /* ]]; then
		echo "Error: shared directory must be an absolute path." >&2
		exit 1
	fi

	if [[ ! -d "$SHARED_HOST_DIR" ]]; then
		echo "Error: shared directory does not exist: $SHARED_HOST_DIR" >&2
		exit 1
	fi

	require_command limactl
	require_command ruby
}

update_aliases() {
	mkdir -p "$(dirname "$ZSHRC")"
	touch "$ZSHRC"

	awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
  $0==s {skip=1; next}
  $0==e {skip=0; next}
  !skip {print}
' "$ZSHRC" >"${ZSHRC}.tmp"
	mv "${ZSHRC}.tmp" "$ZSHRC"

	cat >>"$ZSHRC" <<ALIASES

# >>> agentex aliases >>>
alias ,agent-vm-shell='limactl shell --workdir /home/lima.guest ${INSTANCE_NAME}'
alias ,agent-vm-start='limactl start ${INSTANCE_NAME}'
alias ,agent-vm-stop='limactl stop ${INSTANCE_NAME}'
alias ,agent-vm-status='limactl list'
# <<< agentex aliases <<<
ALIASES
}

configure_existing_instance() {
	local lima_yaml="$HOME/.lima/${INSTANCE_NAME}/lima.yaml"

	ruby - "$lima_yaml" "$SHARED_HOST_DIR" "$SHARED_GUEST_DIR" <<'RUBY'
require "yaml"

config_path = ARGV.fetch(0)
shared_host_dir = ARGV.fetch(1)
shared_guest_dir = ARGV.fetch(2)

config = YAML.load_file(config_path)
config["plain"] = false
config["mounts"] = [
  {
    "location" => shared_host_dir,
    "mountPoint" => shared_guest_dir,
    "writable" => true,
  },
]

File.write(config_path, YAML.dump(config))
RUBY

	limactl stop "$INSTANCE_NAME" >/dev/null 2>&1 || true
	limactl start "$INSTANCE_NAME"
}

create_shared_instance() {
	limactl start \
		--name="$INSTANCE_NAME" \
		--mount-only "${SHARED_HOST_DIR}:w" \
		--set ".mounts[0].mountPoint = \"${SHARED_GUEST_DIR}\"" \
		template:fedora
}

parse_args "$@"
validate_shared_dir

update_aliases

echo "Updated agentex aliases in $ZSHRC"
if [[ -n "$SHARED_HOST_DIR" ]]; then
	if [[ -f "$HOME/.lima/${INSTANCE_NAME}/lima.yaml" ]]; then
		configure_existing_instance
		echo "Updated Lima shared mount: $SHARED_HOST_DIR -> $SHARED_GUEST_DIR"
	else
		create_shared_instance
		echo "Created Lima instance '$INSTANCE_NAME' with shared mount: $SHARED_HOST_DIR -> $SHARED_GUEST_DIR"
	fi
else
	echo "Shared host directory support remains off by default."
fi

echo "Open a new terminal or run: source $ZSHRC"
