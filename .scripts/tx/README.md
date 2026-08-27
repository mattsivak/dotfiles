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

Create a new tmux session. Prompts for a name if not provided.

```sh
tx new                 # Prompts: "Session name:"
tx new work            # Creates session named "work"
```

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
│   ├── prompt.ts            # Interactive text input
│   └── commands/
│       ├── attach.ts        # Two-step session/window picker
│       ├── exit.ts          # Session killer
│       ├── list.ts          # Session lister
│       ├── new.ts           # Session creator
│       └── rename.ts        # Session renamer
```

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
