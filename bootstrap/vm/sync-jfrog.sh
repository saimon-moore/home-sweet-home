#!/usr/bin/env bash
set -euo pipefail

if ! command -v limactl >/dev/null 2>&1; then
	echo "Error: limactl is required but was not found on PATH." >&2
	exit 1
fi

url_encode() {
	local raw="$1"
	local encoded=""
	local i ch byte

	for ((i = 0; i < ${#raw}; i++)); do
		ch="${raw:i:1}"
		case "$ch" in
		[a-zA-Z0-9.~_-])
			encoded+="$ch"
			;;
		*)
			printf -v byte '%%%02X' "'$ch"
			encoded+="$byte"
			;;
		esac
	done

	printf '%s' "$encoded"
}

INSTANCE_NAME="dev"
JFROG_HOST=""
JFROG_REALM="Artifactory Realm"
RUBY_HOST=""
NPM_REGISTRY=""
NPM_SCOPE=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--vm-name)
		INSTANCE_NAME="$2"
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
	--npm-registry)
		NPM_REGISTRY="$2"
		shift 2
		;;
	--npm-scope)
		NPM_SCOPE="$2"
		shift 2
		;;
	-h | --help)
		cat <<'USAGE'
Usage: bootstrap/vm/sync-jfrog.sh --host HOST [options]

Options:
  --host HOST              JFrog host (required).
  --realm REALM            JFrog auth realm (default: "Artifactory Realm").
  --ruby-host HOST         Bundler registry host (default: --host).
  --npm-registry URL       npm registry URL on JFrog (e.g.
                           https://jfrog.example.com/artifactory/api/npm/npm/).
                           Enables the npm auth block in ~/.npmrc.
  --npm-scope NAME         Scope for the npm registry. When set, writes
                           "@NAME:registry=URL" instead of "registry=URL".
  --vm-name NAME           Lima instance name (default: "dev").
USAGE
		exit 0
		;;
	*)
		echo "Error: unknown argument '$1'." >&2
		exit 1
		;;
	esac
done

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

BUNDLE_USERNAME_ENCODED="$(url_encode "$JFROG_OIDC_USER")"
BUNDLE_TOKEN_ENCODED="$(url_encode "$JFROG_OIDC_TOKEN")"
BUNDLE_CREDENTIALS_ENCODED="$BUNDLE_USERNAME_ENCODED:$BUNDLE_TOKEN_ENCODED"

NPM_REGISTRY_HOST_PATH=""
if [[ -n "$NPM_REGISTRY" ]]; then
	NPM_REGISTRY_HOST_PATH="${NPM_REGISTRY#*://}"
	NPM_REGISTRY_HOST_PATH="${NPM_REGISTRY_HOST_PATH%/}/"
fi

TMP_REMOTE_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/home-sweet-home-jfrog-sync.XXXXXX")"
cleanup() {
	rm -f "$TMP_REMOTE_SCRIPT"
}
trap cleanup EXIT

{
	printf 'set -euo pipefail\n'
	printf 'JFROG_OIDC_USER=%q\n' "$JFROG_OIDC_USER"
	printf 'JFROG_OIDC_TOKEN=%q\n' "$JFROG_OIDC_TOKEN"
	printf 'JFROG_HOST=%q\n' "$JFROG_HOST"
	printf 'JFROG_REALM=%q\n' "$JFROG_REALM"
	printf 'RUBY_HOST=%q\n' "$RUBY_HOST"
	printf 'BUNDLE_CREDENTIALS_ENCODED=%q\n' "$BUNDLE_CREDENTIALS_ENCODED"
	printf 'NPM_REGISTRY=%q\n' "$NPM_REGISTRY"
	printf 'NPM_REGISTRY_HOST_PATH=%q\n' "$NPM_REGISTRY_HOST_PATH"
	printf 'NPM_SCOPE=%q\n' "$NPM_SCOPE"
	cat <<'EOF'
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
hsh_config_dir="$config_home/home-sweet-home"
bundle_env_host="${RUBY_HOST//-/___}"
bundle_env_host="${bundle_env_host//./__}"
bundle_env_key="BUNDLE_${bundle_env_host^^}"

install -d -m 700 "$hsh_config_dir"

printf "export JFROG_OIDC_USER=%q\n" "$JFROG_OIDC_USER" > "$hsh_config_dir/jfrog-oidc.env"
printf "export JFROG_OIDC_TOKEN=%q\n" "$JFROG_OIDC_TOKEN" >> "$hsh_config_dir/jfrog-oidc.env"
printf "export JFROG_HOST=%q\n" "$JFROG_HOST" >> "$hsh_config_dir/jfrog-oidc.env"
printf "export JFROG_REALM=%q\n" "$JFROG_REALM" >> "$hsh_config_dir/jfrog-oidc.env"
printf "export %s=%q\n" "$bundle_env_key" "$BUNDLE_CREDENTIALS_ENCODED" >> "$hsh_config_dir/jfrog-oidc.env"
chmod 600 "$hsh_config_dir/jfrog-oidc.env"

if [[ -n "$NPM_REGISTRY" ]]; then
	npmrc_path="$HOME/.npmrc"
	touch "$npmrc_path"
	chmod 600 "$npmrc_path"

	# Remove any previous managed block so the write is idempotent.
	tmp_npmrc="$(mktemp)"
	awk '
		/^# BEGIN home-sweet-home jfrog npm auth$/ { skip = 1; next }
		/^# END home-sweet-home jfrog npm auth$/   { skip = 0; next }
		skip != 1
	' "$npmrc_path" > "$tmp_npmrc"
	mv "$tmp_npmrc" "$npmrc_path"
	chmod 600 "$npmrc_path"

	# Trim trailing blank lines that would accumulate on re-run.
	tmp_npmrc="$(mktemp)"
	awk 'NR==FNR { if (NF) last=NR; next } FNR<=last' "$npmrc_path" "$npmrc_path" > "$tmp_npmrc"
	mv "$tmp_npmrc" "$npmrc_path"
	chmod 600 "$npmrc_path"

	{
		[[ -s "$npmrc_path" ]] && printf '\n'
		printf '# BEGIN home-sweet-home jfrog npm auth\n'
		if [[ -n "$NPM_SCOPE" ]]; then
			printf '@%s:registry=%s\n' "$NPM_SCOPE" "$NPM_REGISTRY"
		else
			printf 'registry=%s\n' "$NPM_REGISTRY"
		fi
		printf '//%s:_authToken=%s\n' "$NPM_REGISTRY_HOST_PATH" "$JFROG_OIDC_TOKEN"
		printf '//%s:always-auth=true\n' "$NPM_REGISTRY_HOST_PATH"
		printf '# END home-sweet-home jfrog npm auth\n'
	} >> "$npmrc_path"
	chmod 600 "$npmrc_path"
fi
EOF
} >"$TMP_REMOTE_SCRIPT"

cat "$TMP_REMOTE_SCRIPT" | limactl shell --workdir /home/dev "$INSTANCE_NAME" bash -s

echo "Synced JFrog credentials for dev on VM $INSTANCE_NAME"
echo "Bundler host: $RUBY_HOST"
if [[ -n "$NPM_REGISTRY" ]]; then
	if [[ -n "$NPM_SCOPE" ]]; then
		echo "npm registry (scope @$NPM_SCOPE): $NPM_REGISTRY"
	else
		echo "npm registry: $NPM_REGISTRY"
	fi
fi
