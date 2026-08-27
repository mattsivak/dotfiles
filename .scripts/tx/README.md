# tx

A tmux utility toolkit. Written in TypeScript, runs natively on Node v25+ with zero dependencies.

## Requirements

- Node.js v25+ (native TypeScript support)
- tmux
- fzf (for interactive pickers)

## Installation

The `tx` executable is symlinked to `~/.local/bin/tx`.

```sh
ln -sf ~/dotfiles/.scripts/tx/tx ~/.local/bin/tx
```

## Commands

### `tx attach [target]`

Switch to a tmux session/window using a two-step fzf picker.

```sh
tx attach              # Interactive: pick session, then pick window
tx attach hq-api:2     # Direct: switch to window 2 of hq-api
```

**Interactive flow:**
1. Pick a session (shows window count and active path)
2. Pick a window within that session (shows window name and path)
3. `+ new session` / `+ new window` options at the bottom

`+ new session` runs the same template flow as `tx new` — including the
`promptDir` / `promptName` questions described under [`tx new`](#tx-new-name).
This is the path `prefix w` uses.

When inside tmux uses `switch-client`, otherwise uses `attach-session`.

### `tx exit [name...]`

Kill tmux sessions.

```sh
tx exit                  # Interactive: multi-select sessions to kill (current pre-checked)
tx exit hq-api           # Direct: kill hq-api
tx exit hq-api oc2 work  # Direct: kill several sessions
```

**Interactive flow:**
1. Multi-select checkbox of all sessions; the current session is pre-checked and tagged `(current)`. Space toggles, enter confirms.
2. A single confirm lists every selected session. If the current session is among them, it warns that you will be detached.
3. Non-current sessions are killed first; the current session (if selected) is killed last so the client stays alive through the rest.

ESC at the checkbox cancels without killing anything. ESC at the confirm returns to the checkbox.

### `tx new [name]`

Create a new tmux session — from a template, or a plain named one.

```sh
tx new                      # Interactive: pick a template (or "Custom")
tx new work                 # Creates a plain session named "work"
tx new -t dev               # Apply the "dev" template directly
tx new -t dev --dir=~/code/api   # ...starting in a specific directory
tx new work --dir           # Plain session, but pick its directory first
```

**Flags**

| Flag | Meaning |
| --- | --- |
| `-t NAME`, `--template=NAME` | Apply a template without the picker |
| `-d`, `--dir` | Pick a start directory with a fuzzy folder search |
| `--dir=PATH` | Use `PATH` directly, skipping the picker |
| `-n`, `--name` | Ask what to call the session |
| `--name=NAME` | Use `NAME` directly, skipping the prompt |

### Asking where and what to call it

Both questions are **opt-in per template**:

| Template field | Asks |
| --- | --- |
| `promptDir: true` | *Where should "dev" start?* — fuzzy folder search |
| `promptName: true` | *Session name* — pre-filled with that folder's basename |

A template that sets neither behaves exactly as before. `--dir` / `--name` turn
the prompts on for one run; `--dir=PATH` / `--name=NAME` answer them outright.

The folder is asked **first**, so the name defaults to its basename — pick
`~/code/api` and just press enter to get a session called `api`, or type over it.
ESC on the name step goes back to the folder search; ESC there goes back to the
template list.

The picker is a fuzzy search over:

1. `zoxide` directories, ranked by frecency (if zoxide is installed)
2. every directory under the configured roots, walked with `fd` (or `find`)

Anything you type that is itself a real path (`~/code/thing`, `../sibling`) is
always offered as the first result, so directories outside the walked roots
still work. ESC goes back to the template picker.

| Env var | Default | Meaning |
| --- | --- | --- |
| `TX_DIR_ROOTS` | `$HOME` | Colon-separated roots to walk |
| `TX_DIR_DEPTH` | `4` | Max walk depth |

Pickers size their list to the terminal minus the prompt and help lines, and
truncate long paths to the terminal width, so the search input stays on screen
in small panes and popups. `--max-rows=N` overrides the list height.

**Placeholders.** Inside a template, `{{dir}}` is the chosen directory and
`{{name}}` the chosen session name (sanitized for tmux — `web.api v2` becomes
`web-api-v2`). They work in session names, session `dir`, window names, window
commands, and `attach`. A session that sets no `dir` of its own simply inherits
the chosen directory, and a single-session template with a literal name is
renamed to the chosen name anyway.

```yaml
name: dev
description: nvim + claude + lazygit in one project
promptDir: true
promptName: true
sessions:
  - name: "{{name}}"
    dir: "{{dir}}"
    windows:
      - name: nvim
        cmd: nvim
      - name: claude
        cmd: claude
      - name: lazygit
        cmd: lazygit
attach: "{{name}}:nvim"
```

`tx new -t dev` asks where to start, then what to call it (offering the folder
name), and gives you a session with three windows all rooted there, attached to
`nvim`.

### `tx list`

List all tmux sessions. Current session is marked with `*`.

```sh
tx list
# hq-api                5 windows
# oc2                   5 windows *
# operator-client       5 windows
```

### `tx rename [session] <new-name>`

Rename a tmux session. With one argument, renames the current session. With two, renames the specified session. Prompts for a name if none given.

```sh
tx rename              # Prompts: 'Rename "current" to:'
tx rename dev          # Renames current session to "dev"
tx rename 5 dev        # Renames session "5" to "dev"
```

## Tmux keybinding

`prefix w` opens `tx attach` in a popup (replaces the default window list):

```tmux
# in ~/.tmux.conf
unbind w
bind w display-popup -E -x C -y C -w 80% -h 70% "/Users/mattsivak/.local/bin/tx attach"
```

## Project structure

```
tx/
├── tx                       # Entry point (executable)
├── src/
│   ├── cli.ts               # Command routing and help
│   ├── tmux.ts              # Tmux interaction layer
│   ├── templates.ts         # Template load/save + placeholder resolution
│   ├── dirpicker.ts         # Fuzzy directory search (zoxide + fd)
│   ├── paths.ts             # Path expansion, tmux name sanitizing
│   ├── prompts.ts           # ESC-to-go-back prompt wrapper
│   ├── args.ts              # Shared flag parsing
│   └── commands/
│       ├── attach.ts        # Two-step session/window picker
│       ├── exit.ts          # Session killer
│       ├── list.ts          # Session lister
│       ├── new.ts           # Session creator
│       ├── rename.ts        # Session renamer
│       ├── stop.ts          # Tmux server killer
│       └── template.ts      # Template management
```

Templates live in `~/.config/tx/templates/*.yaml`. That directory is stowed
from `.config/tx` in this repo, so templates you create with
`tx template create` are version-controlled automatically.

## Adding a new command

1. Create `src/commands/mycommand.ts`:

```ts
export function mycommand(args: string[]): void {
  // ...
}
```

2. Register it in `src/cli.ts`:

```ts
import { mycommand } from "./commands/mycommand.ts";

// Add to COMMANDS:
mycommand: {
  desc: "Description shown in tx --help",
  fn: mycommand,
},
```
