# Agent Harnesses

Ghostty Agent Forge treats behavior as a provider-neutral contract. Agent Prime
projects the same compact managed policy into each native harness file; GAF
reports whether those projections are current without owning the private policy.

## Coverage Matrix

```zsh
gaf harnesses status
gaf harnesses status --json
gaf harnesses doctor
```

The matrix covers Codex, Claude Code, Gemini CLI, OpenCode, Hermes, Hermes Agent
Ultra, discovered Hermes profiles, OMP, Droid, Pi Coding Agent, Mercury Agent,
and GAF's own agent contract. Missing binaries are reported but do not invalidate
policy projection. `doctor` fails when Prime is missing or any canonical
projection is absent, unreadable, unmanaged, or stale.

## Codex Account Homes

Codex supports isolated state through `CODEX_HOME`. GAF adds a small profile
registry at `~/.config/ghostty-agent-forge/codex-accounts.tsv`:

```zsh
gaf codex add pro ~/.codex-pro-2 --yes
gaf codex list
gaf codex status --all
gaf codex login pro
gaf codex pro
gaf codex run pro -- --help
```

The built-in `default` profile maps to `~/.codex`. Profile commands resolve the
same `codex` binary from `PATH`; profiles isolate authentication and session
state only. When Prime is installed, `gaf codex add` immediately re-renders the
managed policy into every registered Codex home. There is deliberately no GAF
logout command. Native logout remains an explicit provider action scoped with
the intended `CODEX_HOME`.

Other harnesses should use their own provider-supported profile or state-home
mechanism. GAF should not pretend those mechanisms are interchangeable.
