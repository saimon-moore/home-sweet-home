#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
	echo "Error: bootstrap/vm/setup-scala.sh is intended to run inside the Linux VM." >&2
	exit 1
fi

install_coursier_wrapper() {
	local cs_dir jar_path wrapper_path
	cs_dir="$HOME/.local/share/coursier"
	jar_path="$cs_dir/coursier.jar"
	wrapper_path="$HOME/.local/bin/cs"

	mkdir -p "$cs_dir" "$HOME/.local/bin"

	if command -v curl >/dev/null 2>&1; then
		curl -fsSL "https://github.com/coursier/coursier/releases/latest/download/coursier.jar" -o "$jar_path"
	elif command -v wget >/dev/null 2>&1; then
		wget -qO "$jar_path" "https://github.com/coursier/coursier/releases/latest/download/coursier.jar"
	else
		echo "Error: neither curl nor wget is available to install coursier." >&2
		return 1
	fi

	cat >"$wrapper_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if command -v java >/dev/null 2>&1; then
	exec java -jar "$HOME/.local/share/coursier/coursier.jar" "$@"
fi

if command -v mise >/dev/null 2>&1; then
	exec mise exec -- java -jar "$HOME/.local/share/coursier/coursier.jar" "$@"
fi

echo "Error: java is required to run coursier." >&2
exit 1
EOF
	chmod 755 "$wrapper_path"
}

if ! command -v mise >/dev/null 2>&1; then
	echo "Error: mise is required but was not found on PATH. Run ,chezmoi-init first." >&2
	exit 1
fi

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
jfrog_env_file="$config_home/home-sweet-home/jfrog-oidc.env"
coursier_credentials="$config_home/coursier/credentials.properties"
sbt_credentials="$HOME/.ivy2/.credentials"

if [[ -f "$jfrog_env_file" ]]; then
	# shellcheck disable=SC1090
	source "$jfrog_env_file"
fi

if [[ -f "$coursier_credentials" ]]; then
	export COURSIER_CREDENTIALS="$coursier_credentials"
fi

if [[ -f "$sbt_credentials" ]]; then
	export SBT_CREDENTIALS="$sbt_credentials"
else
	echo "Warning: $sbt_credentials is missing. Sync JFrog credentials first with ,sync-jfrog-to-vm if sbt or metals resolution fails." >&2
fi

echo "Ensuring current mise config is trusted and installed"
mise trust "$HOME/.config/mise/config.toml"
mise install

if ! mise exec -- sh -lc 'command -v cs >/dev/null 2>&1'; then
	echo "coursier (cs) is not available from the current mise config; installing Scala prerequisites explicitly"
	mise install java "github:scalameta/scalafmt"
	if ! mise exec -- sh -lc 'command -v cs >/dev/null 2>&1'; then
		echo "Installing coursier manually via coursier.jar"
		install_coursier_wrapper
	fi
fi

if ! command -v cs >/dev/null 2>&1; then
	echo "Error: coursier (cs) is still not available after explicit mise install." >&2
	exit 1
fi

mkdir -p "$HOME/.local/bin"

if mise exec -- sh -lc 'command -v helm_ls >/dev/null 2>&1' && [[ ! -e "$HOME/.local/bin/helm-ls" ]]; then
	ln -s "$(mise exec -- sh -lc 'command -v helm_ls')" "$HOME/.local/bin/helm-ls"
fi

echo "Installing Metals and sbt with coursier"
COURSIER_INSTALL_DIR="$HOME/.local/bin" mise exec -- cs install --install-dir "$HOME/.local/bin" metals sbt

echo "Scala tooling installed"
echo "- sbt: $(command -v sbt)"
echo "- cs: $(command -v cs)"
echo "- scalafmt: $(command -v scalafmt)"
echo "- metals: $(command -v metals)"
