#!/usr/bin/env bash
set -euo pipefail

# One-time host bootstrap for convenient Lima aliases.
# Run on macOS host (not inside the VM).

ZSHRC="$HOME/.zshrc"
BLOCK_START="# >>> agentex aliases >>>"
BLOCK_END="# <<< agentex aliases <<<"

mkdir -p "$(dirname "$ZSHRC")"
touch "$ZSHRC"

awk -v s="$BLOCK_START" -v e="$BLOCK_END" '
  $0==s {skip=1; next}
  $0==e {skip=0; next}
  !skip {print}
' "$ZSHRC" > "${ZSHRC}.tmp"
mv "${ZSHRC}.tmp" "$ZSHRC"

cat >>"$ZSHRC" <<'ALIASES'

# >>> agentex aliases >>>
alias agent-vm-shell='limactl shell dev'
alias agent-vm-start='limactl start dev'
alias agent-vm-stop='limactl stop dev'
alias agent-vm-status='limactl list'
agent-vm-bootstrap() { (cd ~/agentex/macos && ./bootstrap-vm.sh "$@"); }
# <<< agentex aliases <<<
ALIASES

echo "Updated agentex aliases in $ZSHRC"
echo "Open a new terminal or run: source $ZSHRC"
