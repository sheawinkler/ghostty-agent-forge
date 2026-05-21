# Agent Shell Rules

Agents call shells differently than humans. The terminal setup must be safe for both.

## Rules

- Non-TTY shells must not load ZLE widgets.
- TTY-only tools include fzf keybindings, fzf-tab widgets, autosuggestions, and syntax highlighting.
- Shell startup must not prompt for updates.
- Runtime managers should lazy-load.
- Completion should use zsh-native functions before bash completion bridges.
- Shell startup should be measurable with `zsh -ic exit`.

## Verification

```zsh
zsh -ic 'print START_OK'
zsh -ic 'whence -w _brew _docker _cargo _uv _pnpm _rg _fd _gh _zoxide'
zsh -ic 'autoload -Uz compaudit; compaudit'
for i in {1..5}; do /usr/bin/time -p zsh -ic exit; done
```

Warm startup target: under `500ms`.

