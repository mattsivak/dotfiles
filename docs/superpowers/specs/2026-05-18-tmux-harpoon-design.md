# tmux-harpoon — Design

Date: 2026-05-18
Status: Approved

## Goal

A harpoon-style, manually-curated focus list for tmux: pin a small set of
"currently working on" targets and flip between them quickly from one popup,
bound to `prefix+u`. Inspired by ThePrimeagen/harpoon (harpoon2 branch).

## Decisions (locked)

- **Trigger:** `prefix+u`. `unbind u` first (currently free; explicit per request).
- **Slot granularity:** window-level. Each slot is a `session:window`.
- **Interaction model:** menu-driven only — one popup is the single entry point.
- **List scope:** one global list shared everywhere (not per-project).
- **Edit mechanism:** `e` opens the backing file in the user's full nvim config.
- **Approach:** fzf-in-popup shell script (matches existing `tx`/`tms`/worktree
  popups; `display-popup -E`).

## Data

- File: `~/.local/share/tmux-harpoon/list`
- Format: plain text, one `session:window_name` per line. Line order = slot
  order. Created on first use (with its parent dir).
- **Extensionless on purpose:** nvim detects no filetype, so conform attaches
  no formatter and will not rewrite lines on `:w`. Parsing is also
  whitespace-tolerant (trim each line; ignore blank lines) as a safeguard.

## Components

1. `~/dotfiles/.scripts/tmux_harpoon.sh`
   - Default invocation: render + run the fzf popup.
   - `tmux_harpoon.sh add` — append current `#{session_name}:#{window_name}`
     if not already present (idempotent dedupe). Reusable for a future direct
     keybind.
   - `tmux_harpoon.sh jump N` — resolve and switch to slot N.
2. tmux glue in `~/dotfiles/.tmux.conf`:
   ```
   unbind u
   bind u display-popup -E -x C -y C -w 80% -h 70% "~/dotfiles/.scripts/tmux_harpoon.sh"
   ```

## Popup behaviour

Rendered list, fzf with search disabled (curated list, digits free for jumps):

```
tmux-harpoon ─────────────────────────────
  1  ● lm8352-operator-client:nvim
  2  ● hq-api:server
  3  ✗ dev-env:logs
───────────────────────────────────────────
 1-9 jump · enter jump · a add · d delete · e edit · q quit
```

- Marker: `●` = session+window currently exist; `✗` = stale (kept, **never
  auto-pruned** — faithful to harpoon; user prunes via `e`).
- `1`–`9` → jump to that slot.
- `Enter` → jump to highlighted row.
- `a` → add current window (idempotent), reload list.
- `d` → delete highlighted row, reload list.
- `e` → open backing file in `nvim` (full LazyVim config); on exit, fzf
  reloads from the file.
- `q` / `Esc` → close popup.

## Jump resolution

For slot N's `sess:win`:

- Session exists and window exists →
  `tmux switch-client -t <sess> \; select-window -t <sess>:<win>`,
  then exit (popup closes via `-E`).
- Target missing → brief in-popup message; stay open.

Window resolved by **name**. If a session has duplicate window names, the
first match wins (documented limitation; acceptable for a curated focus list).

## Out of scope (YAGNI)

- Per-project / per-cwd lists.
- next/prev cycling.
- Telescope-style fuzzy search over all windows.
- JSON store.
- Direct numbered keybinds outside the popup (subcommands exist so this is a
  trivial future add if wanted).

## Testing

- `bats` (or plain shell-assert) for pure logic:
  - `add` appends and dedupes.
  - `jump N` resolves the correct `sess:win` and emits the correct tmux
    command, verified against a fake `tmux` shim on `PATH`.
  - stale detection (`●` vs `✗`) given a shim with a known session/window set.
- fzf/popup presentation layer verified manually.

## Risks / notes

- `display-popup -E` runs the script attached to the calling client;
  `switch-client`/`select-window` target that client (same pattern as the
  existing `tx`/`tms` popups, known-good).
- **tmux does NOT expand `#{...}` in a `display-popup` shell-command**
  (only in option args like `-d`/`-T`). The origin `session:window` is
  therefore resolved inside the script via
  `tmux display-message -p '#{session_name}:#{window_name}'`, not passed as
  a binding argument. `harpoon_add` also rejects values containing `#{` or
  lacking a colon (defense in depth so a bad origin can never be persisted).
  (Post-merge correction: the original plan passed format args to the
  script, which tmux left literal; fixed by self-resolving the origin.)
- fzf is already a hard dependency of the user's tmux setup.
- `--clean` nvim was benchmarked ~3x faster (~29ms vs ~90ms) but the user
  chose the full config for muscle-memory; the extensionless-file safeguard
  above covers the conform/LSP concern.
