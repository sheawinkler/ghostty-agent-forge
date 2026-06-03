# Ghostty Agent Forge by ContextLattice

A Ghostty-native command deck for making local AI agents visible, memory-connected, and operationally reliable.

Ghostty Agent Forge gives local AI agents terminal visibility, stable shell tools, and ContextLattice memory hooks on macOS.

## What It Does

Ghostty Agent Forge bootstraps a macOS terminal workstation for agentic development:

- Ghostty-first terminal setup with zsh and Homebrew.
- Fast zsh startup with native completions, fzf-tab, zoxide, autosuggestions, and syntax highlighting.
- Agent-safe shell behavior for Codex, Claude Code, background workers, launchd jobs, and non-TTY shells.
- ContextLattice-aware defaults for memory search, preflight checks, and local agent identity.
- macOS TCC/FDA diagnostic rules so file-access failures are not mistaken for broken zsh or Unix permissions.
- Reproducible setup scripts for cloning the same terminal environment on another Mac.

## Why This Exists

Local AI agents live and die by terminal quality.

If the shell is slow, noisy, over-permissioned, under-permissioned, or full of interactive prompts, agents waste cycles and fail in ways that look like reasoning failures. This repo treats the terminal as part of the agent runtime: observable, reproducible, and safe for both humans and background agent processes.

ContextLattice provides the memory and coordination plane. Ghostty Agent Forge provides the macOS terminal forge around it.

ContextLattice: https://github.com/sheawinkler/ContextLattice

## Quick Start

Run a dry run first:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --dry-run
```

Then apply:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh
exec zsh -l
```

If Homebrew is not installed:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --install-homebrew
```

If you want to skip the ContextLattice prompt:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --no-contextlattice-prompt
```

To explicitly clone the free public ContextLattice repo:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --install-contextlattice
```

After install, the `gaf` CLI is available from `~/.local/bin/gaf`:

```zsh
gaf doctor
gaf resources status
gaf resources tools --missing-only
gaf memory preflight
gaf bench 5
gaf rules
```

## Installation Profiles

Ghostty Agent Forge assumes two storage profiles:

- `internal-ssd`: keep Ghostty, Homebrew, zsh modules, completions, launchers, app bundles, and small fast state local.
- `external-ssd`: keep large data, logs, archives, backups, sealed telemetry partitions, and bulk model/data stores external.

For agent-heavy machines, do not put core terminal/runtime tools on the same external path that is handling high-write ingest. A Thunderbolt or PCIe external SSD can have excellent bandwidth while still suffering from APFS metadata churn, fseventsd pressure, SQLite WAL/checkpoint contention, and page-cache thrash when live writes and heavy queries hit the same volume.

High-write pipelines should use a two-lane layout:

```text
hot lane   = append-only ingest, minimal readers
query lane = sealed partitions, indexes, summaries
```

More detail: `docs/install-storage-profiles.md`.

## Installed Tool Stack

The bootstrap installs:

```zsh
brew install spaceship fzf fzf-tab zsh-autosuggestions zsh-syntax-highlighting zoxide direnv fd ripgrep docker-completion jq gh
```

It can optionally install:

```zsh
brew install --cask ghostty
```

For heavy local workloads, it can also install the resource-ops stack:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --resource-tools
gaf resources ensure --yes
```

Resource tools are intentionally low-bloat and terminal-native: `btop`, `procs`,
`smartmontools`, `dust`, `dua-cli`, `dysk`, `ncdu`, `gdu`, `rclone`, `restic`,
`watchman`, `hyperfine`, and `yq`.

## Shell Architecture

The script writes modular zsh files under `~/.config/ghostty-agent-forge/zsh/` and sources them from managed blocks in `~/.zprofile` and `~/.zshrc`.

Load order:

1. `.zprofile`: readable-cwd recovery, Homebrew shellenv, OrbStack path, `umask 022`.
2. `.zshrc`: system path floor and existing user config.
3. `completion.zsh`: zsh completion policy before Oh My Zsh calls `compinit`.
4. Oh My Zsh with only `plugins=(git)`.
5. `post-omz.zsh`: fzf-tab and fzf terminal widgets, TTY-only.
6. `contextlattice.zsh`: optional ContextLattice env defaults and helper commands.
7. `tools.zsh`: zoxide, direnv, lazy nvm.
8. `prompt-spaceship.zsh`: Homebrew-managed Spaceship prompt.
9. `late-widgets.zsh`: autosuggestions and syntax highlighting, TTY-only.

## ContextLattice Hooks

The bootstrap can prompt to install ContextLattice from the public repo:

```text
https://github.com/sheawinkler/ContextLattice
```

The `contextlattice.zsh` module adds:

- `CONTEXTLATTICE_ORCHESTRATOR_URL=http://127.0.0.1:8075`
- `MEMMCP_ORCHESTRATOR_URL` compatibility alias
- stable local agent identity defaults
- `cl-health`
- `cl-search`
- `cl-preflight`
- `memwrite`

These helpers are intentionally lightweight. They should not start services, reset permissions, or mutate memory unless explicitly invoked.

## Agent Control Plane

Ghostty Agent Forge ships a small local CLI:

```zsh
gaf doctor                 # shell/tool/TCC/ContextLattice/resource checks
gaf ensure --yes           # install missing required Homebrew formulae
gaf resources status       # current disk, swap, process-state, and warning snapshot
gaf resources snapshot --append
gaf resources hotspots ~/Documents /Volumes/wd_black
gaf resources install-agent --load
gaf bench 5                # zsh startup benchmark
gaf blackbox -- <command>  # run command with local JSONL telemetry
gaf profile export         # export machine capability profile
gaf rules                  # print the agent runtime contract
```

Runtime contract:

```text
config/agent-runtime.json
```

The contract defines shell modes, expected tools, ContextLattice defaults, safety rules, and observability locations. Agents can read it without scanning the whole repo.

## Verification

After installation, run:

```zsh
zsh -n ~/.zshrc
for f in ~/.config/ghostty-agent-forge/zsh/*.zsh; do zsh -n "$f"; done
zsh -ic 'print START_OK; print $SPACESHIP_VERSION'
zsh -ic 'whence -w _brew _docker _cargo _uv _pnpm _rg _fd _gh _zoxide'
zsh -ic 'autoload -Uz compaudit; compaudit'
for i in {1..5}; do /usr/bin/time -p zsh -ic exit; done
tests/smoke.zsh
```

Warm startup target: under `500ms`.

## Resource Ops

`gaf resources` is the local-heavy-load control plane. It keeps routine monitoring
small enough to run from launchd without becoming the workload:

- `gaf resources status` prints a concise health view.
- `gaf resources snapshot --append` writes one compact JSONL record.
- `gaf resources hotspots` runs explicit, on-demand disk triage.
- `gaf resources install-agent --load` installs a user LaunchAgent with
  `LowPriorityIO`, `Nice=10`, and a default five-minute interval.

Default snapshot log:

```text
/Volumes/wd_black/ghostty-agent-forge/resource-monitor/resource-snapshots-YYYYMMDD.jsonl
```

If `/Volumes/wd_black` is not mounted, snapshots fall back to:

```text
~/.local/state/ghostty-agent-forge/resources/
```

More detail: `docs/resource-ops.md`.

## Rules For Agents

- Non-TTY shells must not load terminal widgets that require ZLE.
- Do not install broad bash completion packages for zsh.
- Prefer native zsh completions from Homebrew site-functions.
- Keep runtime managers lazy.
- Disable automatic Oh My Zsh startup prompts.
- Do not reset macOS privacy permissions unless the human explicitly approves it.
- Diagnose TCC/FDA failures before changing Unix file permissions.

## Repository Layout

```text
ghostty-agent-forge/
  README.md
  scripts/
    bootstrap-ghostty-agent-forge.zsh
    contextlattice-preflight.zsh
    macos-tcc-doctor.zsh
  bin/
    gaf
  config/
    agent-runtime.json
  zsh/
    completion.zsh
    post-omz.zsh
    contextlattice.zsh
    tools.zsh
    prompt-spaceship.zsh
    late-widgets.zsh
  docs/
    agent-shell-rules.md
    agent-runtime-contract.md
    contextlattice-integration.md
    flight-recorder.md
    install-storage-profiles.md
    macos-tcc-fda.md
    resource-ops.md
    repo-governance.md
  tests/
    smoke.zsh
```

## License

MIT
