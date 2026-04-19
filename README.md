# home-sweet-home (work)

Dotfiles for my macOS work host plus an isolated Ubuntu LTS dev VM.
The host is intentionally minimal: Homebrew, chezmoi, the `,*` helper
scripts, a curated set of GUI casks, JFrog credential plumbing, and
`nb` for notes. All development — editor, language runtimes, LSPs,
git tooling — lives inside the VM.

---

## One-line install on a fresh Mac

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/saimon-moore/home-sweet-home/main/bootstrap/host/install.sh)
```

Idempotent — safe to re-run.

---

## Prerequisites

Before running the installer:

1. **macOS Sonoma or newer** on an Apple Silicon Mac. `install.sh`
   refuses to run elsewhere.
2. **Xcode Command Line Tools** — the Homebrew install in
   `install.sh` will trigger the CLT installer if missing. Click
   through it when prompted and re-run if needed.
3. **Backed-up SSH key** reachable from the new machine (iCloud,
   external drive, password manager, etc.). After the installer
   finishes you'll copy this into `~/.ssh/`:
   - `id_ed25519` (+ `.pub`) — Onlyfy/XING identity and signing
     key. Used directly by the chezmoi-managed `~/.ssh/config` for
     both `github.com` and `source.xing.com`.
4. **Work IT will push** the MDM-managed apps separately via
   Company Portal / Self Service — Cortex XDR, FortiClient, Iru
   Self Service, uniFLOW, authigo2, BeeCore, Phrase desktop. See
   `ADAPTING.md` → *Manual installs*.
5. **A few chezmoi prompt answers** ready:
   - Git author name + email
   - GitHub username (`saimon-moore`)
   - Whether this machine will be used for `develop` (`no` for the
     host, `yes` inside the VM later)
   - Whether you want `opencode` installed

---

## What the installer does

1. Installs Homebrew (non-interactive) if missing.
2. Installs `chezmoi` via Homebrew.
3. `chezmoi init --apply saimon-moore/home-sweet-home` which:
   - Renders every templated dotfile into `$HOME`.
   - Fires `run_once_after_host-brew-bundle.sh.tmpl` → runs
     `brew bundle` against `bootstrap/host/Brewfile` (installs the
     curated brew formulae and 35 GUI casks).
   - Fires `run_once_after_nb-notebooks-bootstrap.sh.tmpl` → clones
     the `xing` nb notebook from `git@github.com:saimon-moore/nb`
     into `~/.nb/xing`.
   - Drops `~/Desktop/home-sweet-home.md` (a daily-use quick
     reference).
4. Runs `,verify` so you see a colour-coded pass/fail summary before
   the next-steps instructions print.

The Homebrew bundle step can take a while on first run and will
occasionally pause for macOS to ask permission for a cask install
(accessibility, input monitoring, etc.). Approve and let it resume.

---

## Post-install

1. **Open a new terminal.** Shell PATH changes and integrations load
   on shell start, not mid-session.
2. **Drop your SSH keys into `~/.ssh/`:**
   ```bash
   chmod 700 "$HOME/.ssh"
   cp <backup>/id_ed25519     "$HOME/.ssh/"
   cp <backup>/id_ed25519.pub "$HOME/.ssh/"
   chmod 600 "$HOME/.ssh"/id_ed25519
   chmod 644 "$HOME/.ssh"/id_ed25519.pub
   ```
   The nb bootstrap hook clones over `git@github.com:...` and the
   chezmoi-managed `~/.ssh/config` routes github.com through this
   key, so the file must be in place before `chezmoi apply` (or
   re-apply afterwards with `,chezmoi-init`).
   Confirm with `,verify`.
3. **Create the dev VM:** `,create-vm`. This provisions lima with
   the Ubuntu LTS template defined in `lima/dev-ubuntu.yaml`.
4. **Open the VM:** `,dev`.
5. **Bootstrap `dev` inside the VM** (one time):
   ```bash
   mkdir -p "$HOME/.ssh"
   chmod 700 "$HOME/.ssh"
   ssh-keygen -q -t ed25519 -N '' -C "dev@dev" -f "$HOME/.ssh/id_ed25519"
   chezmoi init --apply saimon-moore/home-sweet-home
   mise install
   chezmoi apply
   ```
   Answer `develop=yes` and use the same identity as on the host.
6. **Sync JFrog credentials into the VM** when you need private
   artifact access — see the JFrog section below.
7. **MDM / manual installs** from `ADAPTING.md` → *Manual installs*.
   Most of these are delivered by IT; Paseo is the only one you
   install by hand.

---

## Verify

`,verify` on the host checks:

- Homebrew, chezmoi, git installed
- Spot-check of Brewfile CLIs (`eza`, `fzf`, `rg` (from ripgrep), `fd`,
  `lazygit`, `lima`, `gh`, `jq`, `bat`, `nb`)
- `chezmoi status` — no pending changes
- Git aliases loaded (`git pam` et al.) + `commit.gpgsign = true`
- `~/.ssh/config` references `id_ed25519` and the key file is
  present
- `~/.nb/xing` is a real git repo
- lima dev VM exists
- `~/Desktop/home-sweet-home.md` is in place

Exits non-zero on any hard failure so you can wire it into scripts or
CI.

---

## Daily use

See `~/Desktop/home-sweet-home.md` — that's where the real cheatsheet
lives now. Short version:

- `,dev` enters the dev VM shell (a zellij session).
- `,cheatsheet` prints the full terminal-tool keybinding reference.
- `,chezmoi-update` pulls this repo and applies.
- `,verify` re-runs the health check.

Daily commands, VM networking, the terminal IDE stack, `nb` basics,
and the JFrog sync flow are all covered on the Desktop README.

---

## AI coding harnesses

The `,zagent` zellij layout opens a `,agent` pane, which routes to
whichever AI coding harness is currently selected. Switch at any time
with `,agent-select`.

### Installed harnesses (work fork)

- **opencode** — installed unconditionally, both on the host via the
  Brewfile (`brew "opencode"`) and inside the dev VM via mise
  (`opencode = "latest"`).
- **codex** — installed on the host via `cask "codex"` and in the VM
  via mise (`"npm:@openai/codex" = "latest"`).

Both are always available. The shim just decides which one launches
when you invoke `,agent`.

### Switching

```bash
,agent-select              # show the current selection + availability of each
,agent-select codex        # persist a selection (sticks across shells)
,agent-select --clear      # drop the persistent selection; ,agent falls back to opencode
```

One-shot override without persisting:

```bash
AGENT_HARNESS=codex ,agent
```

`,zagent` always honours whatever `,agent-select` currently says.

### Adding a new harness

1. **Install its CLI.** Add a line to `bootstrap/host/Brewfile`
   (macOS host) and/or `chezmoi/dot_config/mise/config.toml.tmpl`
   (dev VM) — e.g. `"npm:@some-org/foo-agent" = "latest"`.
2. **Register the binary name.** Append it to `KNOWN_HARNESSES`
   near the top of `chezmoi/dot_local/bin/executable_,agent-select`.
3. `chezmoi apply`.

### Skills (`openskills`)

Agent skills live centrally in `~/.agent/skills/` and are managed by
[openskills](https://github.com/numman-ali/openskills). This repo
commits:

- `chezmoi/dot_agent/openskills-manifest.txt` — the list of skill
  names this machine should have.
- `chezmoi/dot_agent/skills/<name>/.openskills.json` — the origin
  metadata openskills needs to fetch each skill.

After every `chezmoi apply`, the
`run_onchange_after_openskills-bootstrap.sh.tmpl` hook reconciles disk state
against the manifest:

1. reads the unique `source` values from the committed
   `.openskills.json` files,
2. runs `npx openskills install <source> --universal` for each,
3. prunes any skill dir on disk whose name is not in the manifest,
4. regenerates `~/.agent/AGENTS.md` via `npx openskills sync`.

Run it manually with `chezmoi apply` or just `npx openskills install
<source> --universal` for ad-hoc additions — then `chezmoi add
~/.agent/skills/<name>/.openskills.json` and update the manifest to
persist the change.

---

## JFrog credentials → VM

JFrog credentials stay sourced from 1Password on the host and are
copied explicitly into the VM when needed. The host shell provides
`,jfrog_oidc_env`, which exports `JFROG_OIDC_USER` and
`JFROG_OIDC_TOKEN`.

```bash
,jfrog_oidc_env
,sync-jfrog-to-vm --host your.jfrog.example.com
```

If Ruby gems use a different host than the primary JFrog host, pass
`--ruby-host` too.

To also wire npm up to a JFrog npm registry, pass `--npm-registry`:

```bash
,sync-jfrog-to-vm \
  --host your.jfrog.example.com \
  --npm-registry https://your.jfrog.example.com/artifactory/api/npm/npm-virtual/
```

For a scoped registry (recommended when JFrog only hosts your own
packages and public packages still come from npmjs), add
`--npm-scope company`. The sync then writes
`@company:registry=...` instead of a global `registry=...` line.

The sync writes two files inside the VM:

- `~/.config/home-sweet-home/jfrog-oidc.env` — sourced automatically
  by the VM shell. Exposes `JFROG_OIDC_USER`, `JFROG_OIDC_TOKEN`,
  `JFROG_HOST`, `JFROG_REALM`, and a Bundler `BUNDLE_<host>`
  variable.
- `~/.npmrc` — only touched when `--npm-registry` is passed. Auth
  lines go between `# BEGIN home-sweet-home jfrog npm auth` /
  `# END home-sweet-home jfrog npm auth` sentinels, so re-running
  the sync replaces the block idempotently and leaves the rest of
  the file alone. `.npmrc` is managed as `create_` in chezmoi
  (created once with `ignore-scripts=true`, never overwritten), so
  the auth lines persist across `chezmoi apply`.

---

## Migrating old clones away from `github-onlyfy`

Earlier versions of this repo's SSH config defined a `github-onlyfy`
alias that routed `git@github-onlyfy:...` URLs through the Onlyfy
key. The current setup drops the alias and instead points
`Host github.com` directly at `id_ed25519`, since this machine
only ever needs that one key for github.com.

If you restore work repos from a backup that was originally cloned
under the old setup, their remotes will still look like
`git@github-onlyfy:owner/repo.git` and `git fetch`/`git push` will
fail once the alias is gone. Use:

```bash
,migrate-github-onlyfy-remotes ~/code            # dry-run, prints proposed rewrites
,migrate-github-onlyfy-remotes --apply ~/code    # actually rewrites the URLs
```

The script walks the given directory recursively, finds every git
repo, and for each remote URL of the form `git@github-onlyfy:...`
runs `git remote set-url` to replace the host with `github.com`.
Both fetch and push URLs are updated. Safe to re-run; only matching
URLs are touched.

---

## Manual chezmoi init (without the one-liner)

```bash
# Install Homebrew (https://brew.sh) yourself, then:
brew install chezmoi
chezmoi init --apply saimon-moore/home-sweet-home
```

`chezmoi` can read this repo directly from GitHub because the repo
root has `.chezmoiroot` pointing at `chezmoi/`.

---

## OAuth browser auth in the VM

Every OAuth-based harness (codex, opencode, claude-code) spins up a
local HTTP listener on `127.0.0.1:<port>` and redirects the browser
to it after login. When the harness runs in the VM, the host browser
can't reach that listener, so the redirect lands on a connection
error. **No port forwarding needed** — the callback URL's query
string carries the token, so hitting the URL from inside the VM
completes the flow.

Recipe:

1. Start login in the VM. Depending on harness:
   - codex: `codex login` (or just run `codex` / `,agent` and follow
     the prompt on first use).
   - opencode: `/connect` inside an opencode session.
   - claude-code: `/login` inside claude-code (or first run).

   The harness prints an auth URL.
2. Open the URL on the host Mac and complete sign-in.
3. The browser redirects to `http://localhost:<port>/callback?...`
   and shows a connection error. **Copy the full URL from the
   address bar.**
4. In any VM shell (a new zellij pane, `,dev` in another tab, etc.):

   ```bash
   curl '<paste-the-full-localhost-url-here>'
   ```

The harness's listener inside the VM receives the callback and
finishes auth.

---

## Troubleshooting

- **`,verify` reports failures** → it names what's missing. Usually
  the fix is `chezmoi apply` or `brew bundle --file
  ~/.local/share/chezmoi/bootstrap/host/Brewfile` in a fresh shell.
- **`chezmoi status` non-empty** → `chezmoi diff` to inspect, then
  `chezmoi apply`.
- **VM won't start** → `limactl stop dev; limactl delete dev;
  ,create-vm`. VMs from before the vzNAT change need this recreate.
- **nb notebook clone failed** → the SSH key wasn't in place when
  the hook ran. Fix the key file, then either re-run
  `,chezmoi-init` or touch the script to re-hash it and
  `chezmoi apply`.
- **Cask install hung on permission prompt** → re-run `brew bundle`
  after approving; casks are idempotent.
- **`chezmoi init` with username-only shorthand resolves elsewhere**
  → always use `saimon-moore/home-sweet-home` explicitly.

---

## Other references

- `ADAPTING.md` — customization guide: every prompt, every gate,
  manual-install catalog, opinionated choices at a glance.
- `bootstrap/host/Brewfile` — the full host manifest.
- `bootstrap/host/install.sh` — the one-line installer (you can read
  it end-to-end in <100 lines).
