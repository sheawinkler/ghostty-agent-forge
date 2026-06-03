# Install Storage Profiles

Ghostty Agent Forge supports two install postures: `internal-ssd` and `external-ssd`.

The default recommendation is to keep terminal/runtime tools on the internal SSD and move only large, cold, or sealed data to the external SSD. External SSDs are excellent for capacity, but they should not become the same hot path for app startup, agent shell state, live ingest writes, and heavy analytical reads.

## Profile: internal-ssd

Use `internal-ssd` when the machine has enough free internal space for shell tools, Homebrew, app bundles, and small runtime caches.

Recommended internal placement:

- Ghostty, Homebrew, zsh modules, completions, prompt files, and `gaf`.
- Agent launch scripts and shell startup config.
- Small state needed for fast startup, such as completion dumps and lightweight profile exports.
- Latency-sensitive apps that need macOS TCC/FDA stability.

Keep off the internal SSD when space is tight:

- Large model files.
- Historical logs.
- Raw telemetry archives.
- Docker/OrbStack bulk data, unless the workload requires internal-SSD latency and the machine has enough headroom.
- Yellowstone or similar high-write pipelines.

Operating rules:

- Keep internal free space above `40 GiB` when possible.
- Treat less than `20 GiB` free as degraded mode for local agents.
- Do not install heavy one-off apps just because they are interesting; prefer repo clones, CLI tools, or external archives for experiments.
- Do not fix macOS privacy failures with recursive `chmod` or `chown`.

Agent rules:

- Check free space before installing or building:

```zsh
df -h /System/Volumes/Data
gaf resources status
```

- Prefer `~/.local/state/ghostty-agent-forge/` for small local state only.
- If internal free space is low, ask before adding large casks, SDKs, model weights, build artifacts, or VM/container images.
- Never move `.app` bundles to a symlinked external path as a default fix. That can destabilize macOS privacy prompts, keychain behavior, update flows, and launch services.

## Profile: external-ssd

Use `external-ssd` for large data stores, sealed query partitions, backups, logs, and cold archives.

Recommended external placement:

- Large project datasets.
- Long-horizon logs and snapshots.
- Model archives and non-active model weights.
- Backup repositories and rclone/restic targets.
- Sealed Yellowstone/algotrader partitions.
- ContextLattice or analytics data stores only when the mount is stable and the workload is designed for external I/O.

Avoid external placement for:

- Ghostty.app, terminal app bundles, and core GUI apps.
- Homebrew itself.
- zsh startup files.
- Hot app support data that must survive sleep/wake, launchd restarts, or macOS privacy checks.
- Live files that agents will repeatedly scan while another pipeline is writing them.

Thunderbolt and PCIe external SSDs have high bandwidth, but mixed live writes and heavy queries still compete on SSD queues, APFS metadata, fseventsd, page cache, SQLite WAL/checkpoint behavior, and container/VM I/O paths.

For high-write pipelines such as Yellowstone:

- Keep live writes append-only and sequential.
- Rotate hot files into immutable hourly or daily partitions.
- Query sealed partitions, not hot mutable files.
- Prefer NDJSON or Parquet over giant pretty-printed JSON arrays.
- Maintain a small manifest or index so agents can select partitions before scanning.
- Materialize routine answers into DuckDB, ClickHouse, or indexed SQLite tables instead of rescanning raw logs.
- Run heavy ad hoc queries with lower priority:

```zsh
nice -n 10 taskpolicy -b <query-command>
```

- Avoid memory-mapped scans on actively written files. Use mmap only for sealed/static files.

Example layout:

```text
/Volumes/wd_black/algotrader_rust/live/
  current.ndjson
  runtime_analytics.sqlite

/Volumes/wd_black/algotrader_rust/sealed/
  dt=2026-06-03/hour=00/*.ndjson.zst
  dt=2026-06-03/hour=01/*.ndjson.zst

/Volumes/wd_black/algotrader_rust/query/
  parquet/
  duckdb/
  manifests/
```

Agent rules:

- Verify the mount before assuming external storage exists:

```zsh
test -d /Volumes/wd_black && diskutil info /Volumes/wd_black | sed -n '1,80p'
```

- Treat missing external mounts as degraded mode, not as permission breakage.
- Do not recursively scan external roots during active ingest unless the human explicitly asks for disk triage.
- Prefer `gaf resources hotspots <specific-path>` over broad `du` on the full volume.
- Query sealed data first; only touch hot live data with small, targeted commands.
- Use Time Machine and Spotlight exclusions for high-churn data paths, but do not rely on exclusions to solve write amplification.

## Decision Rule

Use this split unless the human gives a different machine-specific policy:

```text
internal-ssd = shell, apps, Homebrew, launchers, small fast state
external-ssd = big data, logs, archives, sealed partitions, backups
```

If a workload needs both high write throughput and frequent analytical reads, design a two-lane path:

```text
hot lane   = append-only ingest, minimal readers
query lane = sealed partitions, indexes, summaries
```

