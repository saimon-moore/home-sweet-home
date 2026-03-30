# Minimal AI Pairing Setup

**macOS → Lima (isolated Fedora VM) → OpenCode → GPT-5.4**

---

## Lima (Isolated)

### Setup

Install and create an isolated VM (no host mounts):

```bash
brew install lima
limactl start --name=dev --plain --mount-none template:fedora
limactl shell dev
```

Why this is isolated:
- `--mount-none` removes host directory mounts.
- `--plain` disables Lima integration features (mounts/forwards/containerd defaults), reducing host coupling.

Optional shared workspace mount:

Host sharing is off by default. If you want to edit code on the macOS host while the agent works on the same tree inside the VM, `bootstrap-host.sh` can create or update the Lima instance with a writable mount at `~/Code`:

```bash
cd ~/agentex/macos
./bootstrap-host.sh --shared-dir /Users/myuser/Code
```

If the `dev` instance does not exist yet, the script creates it with the mount already configured during `limactl start`. If it already exists, the script updates `~/.lima/dev/lima.yaml` and restarts the instance.

The resulting mount looks like this inside the guest:

```yaml
mounts:
  - location: "/Users/myuser/Code"
    mountPoint: "/home/lima.guest/Code"
    writable: true
```

If you prefer to configure the mount manually, restart the instance after editing `~/.lima/dev/lima.yaml`:

```bash
limactl stop dev
limactl start dev
```

Notes:
- With `vmType: vz`, Lima uses `virtiofs` by default for mounts on macOS.
- When using a custom `mountPoint`, open the shell with an explicit guest working directory so Lima does not try to reuse the host path:

```bash
limactl shell --workdir /home/lima.guest dev
```

Inside the VM, the only required manual prerequisite is:

```bash
sudo dnf install -y git
```


### Rebuild

Nuke and rebuild anytime:

```bash
limactl delete --force dev
limactl start --name=dev --plain --mount-none template:fedora
```

---

## Setup the agent

Only do this once to setup the VM environment:

```bash
limactl shell dev
cd ~
git clone https://github.com/david-krentzlin/agentex.git
cd agentex/macos
./bootstrap-vm.sh your-email@example.com "Your Name"
```

`bootstrap-vm.sh` will:
- install system dependencies via `dnf` (`ripgrep`, `fd-find`, `jq`, build tools, `curl`, `openssh-clients`)
- install `mise` (if missing)
- install/update global tools via `mise` (`opencode`, `ruby`, `go`, `starship`)
- configure Ruby in `mise` to prefer precompiled binaries (`ruby.compile=false`)
- install OpenCode templates in `~/.config/opencode/` (`opencode.json`, `AGENTS.md`, `commands/*`, `skills/*`)
- configure global git (`user.email`, `user.name`, default branch)
- generate a dedicated VM SSH key for GitHub and print the public key for copy/paste
- configure `~/.bashrc` with agent shell marker prompt setup

Optional host aliases (run on macOS host):

```bash
cd ~/agentex/macos
./bootstrap-host.sh
```

To enable a shared workspace during host bootstrap instead, pass `--shared-dir /absolute/host/path`.

---

## Architecture

### What's always in context

**AGENTS.md** — concise invariant rules. Covers: no autonomous action, no scope creep, be direct, load skills before workflows.

**Agent prompt** — one sentence per agent. Build defaults to navigator. Plan is read-only.

**Skill descriptions** — five one-line descriptions in the tool listing. The agent sees *what's available*, not full skill content.

### What loads on demand

Skills load their full content only when a `/command` (or the agent) invokes them.

### Isolation + Permissions

The agent runs inside a Lima VM that has no host file mounts. Host filesystem access is not available unless you explicitly add mounts.

`opencode.json` is configured to be more permissive in this isolated VM:
- `edit`: `allow`
- `bash`: `allow` by default
- `webfetch`: `allow`
- A small denylist blocks high-risk commands (`rm -rf`, force push, hard reset, publish)

---

## Skills

| Skill | Purpose | Loaded by |
|-------|---------|-----------|
| `software-design` | General principles: simplicity, naming, SRP, coupling, composition, error handling, API design | `/review`, `/improve` |
| `ddd` | Bounded contexts, ubiquitous language, aggregates, value objects, events | `/review` and `/improve` when domain complexity warrants it |
| `pair-programming` | Driver/navigator roles, handoff protocol, role assignment defaults | `/prototype`, `/improve` |
| `pair-debugging` | Reproduce → hypothesize → narrow → fix → verify | `/debug` |
| `testing` | Match project patterns, write focused tests, TDD protocol | `/test` |

---

## Commands

| Command | Agent | You | Agent role | Skills loaded |
|---------|-------|-----|------------|---------------|
| `/test` | build | Navigate | **Drive** | testing |
| `/check` | build | Navigate | **Drive** | — |
| `/review` | plan | Navigate | Navigate (read-only) | software-design (+ddd) |
| `/prototype <desc>` | build | Navigate | **Drive** | pair-programming |
| `/debug <problem>` | build | Navigate | **Drive** | pair-debugging |
| `/improve <area>` | plan | Drive | Navigate (read-only) | software-design, pair-programming (+ddd) |

For regular development (features, refactors), just talk in Build mode. You drive, the agent navigates.

---

## Daily Use

```bash
limactl shell --workdir /home/lima.guest dev
cd ~/your-project
opencode
```

**Plan something**: Tab → Plan. Discuss. The agent reads code, surfaces issues, suggests approaches.

**Build it**: Tab → Build. You describe what to do. The agent suggests how. The agent can edit and run commands by default.

**Test it**: `/test` — agent runs the suite, reports, hypothesizes on failures.

**Check it**: `/check` — agent runs linters/types/formatters, lists issues.

**Review it**: `/review` — agent reads the diff, flags problems against design principles.

**Prototype**: `/prototype a webhook handler with retry logic` — agent drives, you redirect.

**Debug**: `/debug POST /api/users returns 500 after auth middleware change` — agent follows the protocol.

**Improve**: `/improve error handling in the payment module` — agent analyzes, proposes options.
