# Agent Behavior Packs

Ghostty Agent Forge can install compact behavior packs that make multiple agent harnesses share the same operating contract without copying large rule files into every tool.

## Public/Private Split

- Public GAF contains the installer, status checks, render bridge, and docs.
- Private packs contain proprietary rules, templates, and generated harness blocks.
- ContextLattice supplies runtime memory, policy packs, sessions, hooks, and adoption proof.

The private Sheawinkler pack is expected at:

```text
sheawinkler/contextlattice-agent-prime
```

GAF does not vendor that content into this public repository.

## Install

Install requires the authenticated GitHub login to be `sheawinkler`:

```zsh
gh auth status
gaf behavior install --prime --yes
```

By default this downloads the latest private GitHub release bundle and verifies
the adjacent `SHA256SUMS` file before installation.

For local development of the private pack:

```zsh
gaf behavior install --prime --source ~/Documents/Projects/contextlattice-agent-prime --yes
```

Install locations:

```text
~/.contextlattice/agent-packs/prime/<version>
~/.contextlattice/agent-packs/prime/current
~/.config/ghostty-agent-forge/behavior
```

## Commands

```zsh
gaf behavior status
gaf behavior doctor
gaf behavior render --all
gaf behavior update --yes
```

`render --all` delegates to the installed private pack renderer. The renderer should use managed blocks so existing harness files are preserved.

## Harness Targets

The prime pack renderer owns private managed blocks for:

- Codex: `~/.codex/AGENTS.md`
- Claude Code: `~/.claude/CLAUDE.md`
- Gemini CLI: `~/.gemini/GEMINI.md`
- OpenCode: `~/.config/opencode/AGENTS.md`
- Hermes: `~/.hermes/SOUL.md`
- Hermes Agent Ultra: `~/.hermes-agent-ultra/SOUL.md`
- Existing Hermes profile overrides: `~/.hermes/profiles/*/SOUL.md`
- OMP: `~/.omp/agent/AGENTS.md`
- Droid: `~/.droid/AGENTS.md`
- Pi Coding Agent: `~/.pi-coding-agent/AGENTS.md`
- Mercury Agent: `~/.mercury-agent/AGENTS.md`
- Ghostty Agent Forge: `~/.config/ghostty-agent-forge/AGENTS.md`
- ContextLattice shell/hook env: `~/.contextlattice/agent_prime.env` and `~/.contextlattice/agent_hooks.env`

The private renderer also emits local-only `generated/agent_prime_analysis.md` and `generated/agent_prime_analysis.json` for capability/profile/install-target review.

## Rules For Agents

- Do not paste private pack contents into public repos or public issues.
- Do not replace full user harness files; write managed blocks only.
- Keep always-loaded behavior compact and point to ContextLattice for expanded context.
- Run `gaf behavior doctor` after install or update.
