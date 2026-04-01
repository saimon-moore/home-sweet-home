# home-sweet-home

Setup my environments for both work and private context.
Manage dotfiles and unified tools.


## First-Time Setup

### Work

1. Clone this repo on your mac.
2. Run the host bootstrap.

```bash
./bootstrap/host/macos.sh --context work
```

3. Create the Fedora VM.

```bash
./bootstrap/vm/macos-create-fedora.sh --context work
```

4. From the host, apply the `dev` user config into the VM.

```bash
./bootstrap/vm/apply-user.sh --target dev --context work
```

If `/workspaces/home-sweet-home` is missing in the VM, the helper clones it automatically.

5. From the host, apply the `agent` user config into the VM.

```bash
./bootstrap/vm/apply-user.sh --target agent --context work
```

Run the two helper commands in that order.

6. Open the VM as `dev` or `agent` when you need a shell.

```bash
,dev
,agent
```

Use `,dev` and `,agent` instead of raw `limactl shell` commands.

Repos under `/workspaces` are intended to be shared between `dev` and `agent`.

## What you get

* Managed dotfiles for your host machine
* A virtual machine that is used to isolate all development from the host system 
* Managed dotfiles for the dev user in the dev vm
* [Optional] an agent setup for a development agent using opencode in the dev vm

## Daily Use

- Open the dev shell with `,dev`
- Open the agent shell with `,agent`
- Keep shared repos under `/workspaces` on the vm
- Pull repo changes in the VM repo checkout under `/workspaces/home-sweet-home`
- Re-run `bootstrap/vm/apply-user.sh` for `dev` or `agent`
- Apply `dev` first, then `agent`, if you are updating both

## Access VM Servers From The Host

Lima forwards guest localhost ports to host localhost, so you can run an app server in the VM and open it in a browser on the host.

Run the server inside the VM and bind it to `127.0.0.1` or `localhost`.

Examples:

```bash
# Rails inside the VM
bin/rails server -b 127.0.0.1 -p 3000

# Open on the host
http://localhost:3000
```

```bash
# Another app inside the VM
./server --host 127.0.0.1 --port 8080

# Open on the host
http://localhost:8080
```

Notes:

- Prefer binding app servers to `127.0.0.1` in the VM
- Use the same port number on the host
- The VM guest IP is not directly reachable from the host with the current Lima network mode

## Sync JFrog Credentials To The VM

JFrog credentials stay sourced from 1Password on the host and are copied explicitly into the VM when needed.

The host shell already provides `,jfrog_oidc_env`, which exports `JFROG_OIDC_USER` and `JFROG_OIDC_TOKEN`.

Sync credentials for a VM user with:

```bash
,jfrog_oidc_env
./bootstrap/vm/sync-jfrog.sh --target dev --host your.jfrog.example.com
./bootstrap/vm/sync-jfrog.sh --target agent --host your.jfrog.example.com
```

The default realm is `Artifactory Realm`. If your setup differs, pass `--realm` explicitly.

If Ruby gems use a different host than Scala/sbt, pass `--ruby-host` too.

The sync writes VM-local files only:

- `~/.config/home-sweet-home/jfrog-oidc.env`
- `~/.ivy2/.credentials`
- `~/.config/coursier/credentials.properties`

On VM work shells, `SBT_CREDENTIALS` and `COURSIER_CREDENTIALS` are exported automatically when those files exist.
