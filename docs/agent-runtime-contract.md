# Agent Runtime Contract

Ghostty Agent Forge exposes a machine-readable runtime contract at:

```text
config/agent-runtime.json
```

After installation:

```zsh
gaf rules
```

## Contract Goals

- Tell agents which shell mode they are in.
- Tell agents which tools should exist.
- Tell agents where ContextLattice lives.
- Tell agents what must never be done automatically.
- Make terminal capabilities inspectable without loading large docs.

## Required Agent Behavior

Agents should run:

```zsh
gaf doctor
gaf memory preflight
gaf behavior status
```

If ContextLattice is unavailable, continue from local evidence and report degraded-memory mode.

If `gaf doctor` reports blocked Documents or external-volume access, diagnose macOS Privacy & Security before changing Unix mode bits.

Private behavior packs are optional and intentionally not vendored into this
public repo. When installed, agents should use:

```zsh
gaf behavior doctor
```

to verify managed harness blocks and ContextLattice behavior-pack support.

## Shell Modes

`human_interactive` may load completion UI, prompt, autosuggestions, syntax highlighting, and fzf widgets.

`agent_noninteractive` must not load interactive prompts, update checks, or ZLE-only widgets.

`launchd_background` must use absolute paths and explicit environment.

`ssh_remote` must avoid local app assumptions.
