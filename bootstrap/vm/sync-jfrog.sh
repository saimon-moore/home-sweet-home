#!/usr/bin/env bash
set -euo pipefail

if ! command -v limactl >/dev/null 2>&1; then
	echo "Error: limactl is required but was not found on PATH." >&2
	exit 1
fi

INSTANCE_NAME="dev"
TARGET=""
JFROG_HOST=""
JFROG_REALM="Artifactory Realm"
RUBY_HOST=""

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
	--host)
		JFROG_HOST="$2"
		shift 2
		;;
	--realm)
		JFROG_REALM="$2"
		shift 2
		;;
	--ruby-host)
		RUBY_HOST="$2"
		shift 2
		;;
	-h | --help)
		echo "Usage: bootstrap/vm/sync-jfrog.sh --target {dev|agent} --host HOST [--realm REALM] [--ruby-host HOST] [--vm-name NAME]"
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

if [[ -z "$JFROG_HOST" ]]; then
	echo "Error: --host is required." >&2
	exit 1
fi

if [[ -z "$RUBY_HOST" ]]; then
	RUBY_HOST="$JFROG_HOST"
fi

if [[ -z "${JFROG_OIDC_USER:-}" || -z "${JFROG_OIDC_TOKEN:-}" ]]; then
	if ! command -v op >/dev/null 2>&1; then
		echo "Error: JFROG_OIDC_USER and JFROG_OIDC_TOKEN are not set. Run ,jfrog_oidc_env first or install 1Password CLI (op)." >&2
		exit 1
	fi

	echo "Exporting jfrog credentials from 1Password"
	JFROG_OIDC_USER="$(op read "op://Private/JFROG_OIDC/username")"
	JFROG_OIDC_TOKEN="$(op read "op://Private/JFROG_OIDC/password")"
	if [[ -z "$JFROG_OIDC_USER" || -z "$JFROG_OIDC_TOKEN" ]]; then
		echo "Error: failed to read JFrog credentials from 1Password." >&2
		exit 1
	fi
fi

TMP_PAYLOAD="$(mktemp "${TMPDIR:-/tmp}/home-sweet-home-jfrog.XXXXXX")"
cleanup() {
	rm -f "$TMP_PAYLOAD"
}
trap cleanup EXIT

{
	printf 'JFROG_OIDC_USER=%q\n' "$JFROG_OIDC_USER"
	printf 'JFROG_OIDC_TOKEN=%q\n' "$JFROG_OIDC_TOKEN"
	printf 'JFROG_HOST=%q\n' "$JFROG_HOST"
	printf 'JFROG_REALM=%q\n' "$JFROG_REALM"
	printf 'RUBY_HOST=%q\n' "$RUBY_HOST"
} >"$TMP_PAYLOAD"

limactl shell --workdir /home/dev "$INSTANCE_NAME" sudo -iu "$TARGET" bash -lc '
	set -euo pipefail
	source /dev/stdin
	config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
	hsh_config_dir="$config_home/home-sweet-home"
	coursier_dir="$config_home/coursier"
	ivy_dir="$HOME/.ivy2"
	bundle_env_host="${RUBY_HOST//-/___}"
	bundle_env_host="${bundle_env_host//./__}"
	bundle_env_key="BUNDLE_${bundle_env_host^^}"
	bundle_credentials="${JFROG_OIDC_USER}:${JFROG_OIDC_TOKEN}"
	install -d -m 700 "$hsh_config_dir" "$coursier_dir" "$ivy_dir"
	cat > "$hsh_config_dir/jfrog-oidc.env" <<EOF
export JFROG_OIDC_USER=$(printf %q "$JFROG_OIDC_USER")
export JFROG_OIDC_TOKEN=$(printf %q "$JFROG_OIDC_TOKEN")
export JFROG_HOST=$(printf %q "$JFROG_HOST")
export JFROG_REALM=$(printf %q "$JFROG_REALM")
export $bundle_env_key=$(printf %q "$bundle_credentials")
EOF
	chmod 600 "$hsh_config_dir/jfrog-oidc.env"
	cat > "$ivy_dir/.credentials" <<EOF
realm=$JFROG_REALM
host=$JFROG_HOST
user=$JFROG_OIDC_USER
password=$JFROG_OIDC_TOKEN
EOF
	chmod 600 "$ivy_dir/.credentials"
	cat > "$coursier_dir/credentials.properties" <<EOF
jfrog.username=$JFROG_OIDC_USER
jfrog.password=$JFROG_OIDC_TOKEN
jfrog.host=$JFROG_HOST
jfrog.realm=$JFROG_REALM
EOF
	chmod 600 "$coursier_dir/credentials.properties"
' <"$TMP_PAYLOAD"

echo "Synced JFrog credentials for $TARGET on VM $INSTANCE_NAME"
echo "Bundler host: $RUBY_HOST"
