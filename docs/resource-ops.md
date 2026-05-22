# Resource Ops

Ghostty Agent Forge includes a resource layer for Mac workstations that run local agents, live telemetry, Docker/OrbStack, cloud sync, and large external volumes.

## Commands

```zsh
gaf resources status
gaf resources tools --missing-only
gaf resources ensure --yes
gaf resources snapshot --append
gaf resources hotspots ~/Documents /Volumes/wd_black
gaf resources install-agent --load
```

## Tool Stack

The resource stack is deliberately small and terminal-native:

- `btop`: interactive CPU, memory, process, and disk overview.
- `procs`: better process inspection than raw `ps`.
- `smartmontools`: drive SMART inspection through `smartctl`.
- `dust`, `dua-cli`, `dysk`, `ncdu`, `gdu`: fast disk usage triage. Homebrew may expose `gdu` as `gdu-go` when avoiding a `coreutils` conflict.
- `rclone`: cloud sync and remote listing.
- `restic`: deduplicated backup snapshots, including rclone-backed remotes.
- `watchman`: efficient filesystem event detection.
- `hyperfine`: repeatable command benchmarking.
- `yq`: YAML/JSON manipulation for agent config and launchd-adjacent files.

macOS built-ins remain part of the contract: `iostat`, `fs_usage`, `iotop`, `powermetrics`, and `lsof`.

## Snapshot Policy

`gaf resources snapshot --append` writes one compact JSONL record. It captures:

- internal and external disk free space
- VM and swap counters
- zombie, stopped, and uninterruptible process counts
- top RSS and CPU processes
- a short `iostat` tail

It does not run recursive disk scans. Expensive scans stay explicit through `gaf resources hotspots`.

Default log:

```text
/Volumes/wd_black/ghostty-agent-forge/resource-monitor/resource-snapshots-YYYYMMDD.jsonl
```

Fallback when the external SSD is not mounted:

```text
~/.local/state/ghostty-agent-forge/resources/
```

## LaunchAgent

Install the monitor:

```zsh
gaf resources install-agent --load
```

Default behavior:

- five-minute interval
- `LowPriorityIO=true`
- `Nice=10`
- runs `~/.config/ghostty-agent-forge/bin/gaf` instead of the checkout under `~/Documents`
- no sudo
- no recursive disk scans
- no network upload

Use a different interval or log root:

```zsh
gaf resources install-agent --load --interval 600 --log-dir /Volumes/wd_black/ghostty-agent-forge/resource-monitor
```

Remove it:

```zsh
gaf resources uninstall-agent
```

## Operating Rules

- Keep telemetry writes batched and append-only.
- Prefer external SSD logs when mounted.
- Keep internal free space above 40 GiB.
- Treat swap above 4 GiB as a warning, not a failure by itself.
- Diagnose macOS TCC/FDA before changing Unix permissions.
- Use `resources hotspots` only when investigating disk pressure.
