# Claude Code Bash Permissions

Ghostty Agent Forge can install a Claude Code Bash approval hook that removes
prompt churn for normal shell work while keeping executable `sudo` behind an
approval prompt.

## Install

Preview first:

```zsh
gaf claude permissions install --dry-run
```

Apply:

```zsh
gaf claude permissions install --yes
```

Verify:

```zsh
gaf claude permissions status
gaf claude permissions doctor
```

Then restart Claude Code and run Claude's `/hooks` and `/permissions` commands.

## Behavior

The installed hook allows:

- non-sudo `Bash` commands;
- `sh`, `bash`, and `zsh` commands when they do not execute sudo;
- all `git` commands;
- all `python`, `python3`, and `python3.x` commands.

The installed hook asks for approval for:

- executable `sudo`;
- executable `sudo` nested inside `sh -c`, `bash -c`, or `zsh -c`.

For `PermissionRequest`, executable `sudo` returns no auto-allow decision so
Claude Code shows its normal approval prompt.

## Files

Default install targets:

```text
~/.claude/hooks/bash-approval.py
~/.claude/settings.json
```

Every applied install backs up existing settings as:

```text
~/.claude/settings.json.bak.YYYYMMDD-HHMMSS
```

For tests or alternate Claude profiles:

```zsh
gaf claude permissions install --yes --claude-dir /tmp/claude-test
gaf claude permissions doctor --claude-dir /tmp/claude-test
```

## Blast Radius

The installer preserves unrelated settings and hooks.

It intentionally changes only this Claude Code surface:

- sets `permissions.defaultMode` to `acceptEdits`;
- adds `Bash` to `permissions.allow` if missing;
- removes existing string rules equal to `Bash` or starting with `Bash(` from
  `permissions.ask` and `permissions.deny`;
- replaces existing `PreToolUse` hook groups whose `matcher` is exactly `Bash`;
- replaces existing `PermissionRequest` hook groups whose `matcher` is exactly
  `Bash`.

It does not edit TCC, Keychain, sudoers, shell startup files, or non-Bash Claude
permission rules.
