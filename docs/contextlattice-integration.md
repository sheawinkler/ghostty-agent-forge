# ContextLattice Integration

Ghostty Agent Forge is designed to make the terminal observable and memory-connected for local AI agents.

ContextLattice is optional, but recommended:

https://github.com/sheawinkler/ContextLattice

## Install Prompt

The bootstrap prompts before cloning ContextLattice:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh
```

To force installation:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --install-contextlattice
```

To skip the prompt:

```zsh
./scripts/bootstrap-ghostty-agent-forge.zsh --no-contextlattice-prompt
```

## Shell Hooks

The `zsh/contextlattice.zsh` module provides:

- local orchestrator defaults
- compatibility aliases for older `MEMMCP_*` callers
- session-aware local agent identity
- `cl-health`
- `cl-search`
- `cl-preflight`
- `memwrite`

The module does not start or install ContextLattice services by itself.

## Agent Rule

Context reads should be explicit, bounded, and labeled. If ContextLattice is unreachable or degraded, agents should continue with local evidence and report degraded-memory mode.

