# macOS TCC/FDA Diagnostics

macOS privacy controls can make a healthy shell look broken.

High-signal symptoms:

- `Operation not permitted`
- `unable to read current working directory`
- commands can stat a parent path but cannot traverse into a protected path
- agents fail only in background terminals
- Finder or terminal prompts stop appearing

## Diagnose Before Changing Permissions

Run:

```zsh
./scripts/macos-tcc-doctor.zsh
```

If `~/Documents` or external volumes are blocked, check macOS Privacy & Security for the terminal app and agent host process before changing Unix file permissions.

Do not use recursive `chmod` or `chown` as a first response to a TCC denial.

