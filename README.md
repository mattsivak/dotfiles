# dotfiles

My macOS dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's included

- **zsh** - oh-my-zsh with starship prompt, zoxide, zsh-syntax-highlighting, zsh-autosuggestions
- **tmux** - prefix `C-f`, minimal-tmux-status theme, tms session manager, tpm plugins (managed as submodules)
- **neovim** - LazyVim-based config
- **yabai** - BSP tiling window manager (no gaps, no padding)
- **skhd** - keybindings for yabai using hyper/meh/fn modifiers
- **sketchybar** - custom status bar with battery, clock, power, memory widgets
- **starship** - minimal prompt config

## Setup

```sh
git clone --recurse-submodules https://github.com/mattsivak/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow .
```

If you already cloned without `--recurse-submodules`:

```sh
git submodule update --init --recursive
```

## Key bindings (skhd)

| Modifier | Keys | Action |
|----------|------|--------|
| meh (ctrl+shift+alt) | h/j/k/l | Focus window |
| hyper (ctrl+shift+alt+cmd) | h/j/k/l | Swap window |
| meh | 1-9 | Focus space |
| hyper | 1-9 | Move window to space |
| hyper | f | Toggle float |
| hyper | r | Restart yabai |

## Tmux bindings

| Binding | Action |
|---------|--------|
| `C-f s` | Session switcher (tms) |
| `C-f n` | New session with name |
| `C-f c` | New window in current path |
| `C-f W` | Launch work sessions |
| `C-f Space` | Toggle status bar |
