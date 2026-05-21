# Flight Recorder

`gaf blackbox` runs a command and appends structured execution telemetry:

```zsh
gaf blackbox -- zsh -ic exit
```

Default log:

```text
~/.local/state/ghostty-agent-forge/blackbox.jsonl
```

Each line records:

- timestamp
- host
- cwd
- git branch
- argv
- exit code
- duration
- ContextLattice URL

This is intentionally local-first. It does not upload logs. Pipe or checkpoint the records into ContextLattice only when that is explicitly useful.

## Use Cases

- Prove shell startup latency.
- Catch commands that silently fail in background agents.
- Compare human vs agent terminal behavior.
- Record exact command evidence for debugging.

## Redaction Rule

Do not run credential-bearing commands through `gaf blackbox` unless the command output is already safely redacted. The blackbox records argv, not stdout/stderr.
