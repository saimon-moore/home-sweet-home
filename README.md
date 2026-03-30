# agentex

`agentex` bootstraps an isolated OpenCode development environment. 

The goal is simple: keep your host machine clean, run coding agents inside an isolated VM, and start pairing quickly with a repeatable setup.

## Quickstart

Currently only MacOS is supported. Pure linux setup will follow with a similar architecture.

See [MACOS Instructions](/macos/opencode-lima-setup.md) for details.

Host sharing is off by default. If you want to edit a project on the host while the agent works on it inside the VM, run `macos/bootstrap-host.sh --shared-dir /absolute/host/path` to mount that directory inside the guest at `~/Code`.

## Repository layout

```text
.
├── README.md
└── macos
    ├── bootstrap-host.sh
    ├── bootstrap-vm.sh
    ├── opencode-lima-setup.md
    └── templates
        ├── AGENTS.md
        ├── opencode.json
        └── dot-opencode
            ├── commands
            └── skills
```
