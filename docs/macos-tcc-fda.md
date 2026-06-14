# macOS TCC/FDA Diagnostics

macOS privacy controls can make a healthy shell look broken.

High-signal symptoms:

- `Operation not permitted`
- `unable to read current working directory`
- commands can stat a parent path but cannot traverse into a protected path
- agents fail only in background terminals
- Finder or terminal prompts stop appearing
- prompts repeatedly name `Python`, `Codex`, `Ghostty`, or another launcher

## Hard Boundary

GAF cannot safely and silently grant Full Disk Access, Files & Folders,
Accessibility, Automation, or Developer Tools permissions on an unmanaged Mac.
macOS requires the user to approve those grants in Privacy & Security, unless the
machine is managed by MDM with a PPPC profile. Direct TCC database edits are
unsupported and should not be part of normal setup.

GAF does not need camera or microphone access. Grant media permissions only to
the app that records or captures media.

## Diagnose Before Changing Permissions

Run:

```zsh
gaf tcc status
```

Useful subcommands:

```zsh
gaf tcc targets
gaf tcc panes
gaf tcc open full-disk-access
gaf tcc open accessibility
gaf tcc guide
```

If `~/Documents` or external volumes are blocked, check macOS Privacy & Security
for the terminal app and agent host process before changing Unix file permissions.

## Permission Targets

Grant Full Disk Access to the app that launches agents, usually:

- Ghostty
- Codex.app
- Visual Studio Code, Cursor, or another editor if it launches terminals/agents

Add CLI binaries such as `python3` only if macOS explicitly names that binary in
the prompt. Homebrew-managed binary paths can change after upgrades, so app-level
launcher grants are more stable.

For UI automation, grant Accessibility to the controlling app. For microphone or
camera, do not grant anything to GAF; grant only the app that records or captures
media.

Do not use recursive `chmod` or `chown` as a first response to a TCC denial.
