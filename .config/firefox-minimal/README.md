# minimal firefox

Firefox with the chrome reduced to a tmux-style window list. Everything else is
summoned by keyboard and disappears when you are done with it.

```
┌──────────────────────────────────────────────┐
│ 1 Hacker News  2 Lobsters  3 MDN Web Docs    │  ← 22px, mono, no icons
├──────────────────────────────────────────────┤
│                                              │
│                   page                       │
│                                              │
└──────────────────────────────────────────────┘
```

- **No** title bar, nav bar, back/forward/reload, bookmarks bar, extension
  icons, hamburger menu, favicons, tab close buttons, or new-tab button.
- `Cmd+L` floats a centred `:` prompt over the page — dmenu, not a toolbar.
- `Cmd+F` opens a `/` prompt along the bottom edge.
- Square corners, zero animation, ayu dark, Hack Nerd Font Mono — matching the
  sketchybar/Ghostty/Neovim palette on this machine.

## Install

```sh
./install.sh --dry-run     # see exactly what it will touch
./install.sh               # back up, then install into default-release
./install.sh --uninstall   # restore the backup
```

It writes only `<profile>/chrome/` and `<profile>/user.js`, backing up any
existing copies to `chrome.backup-<timestamp>` first. Quit Firefox before
installing: it rewrites `prefs.js` on exit and will clobber a live edit.

## Keys

Since the buttons are gone, these are the whole interface:

| key | does |
|---|---|
| `Cmd+L` | address bar / search prompt |
| `Cmd+F` | find in page |
| `Cmd+1`…`9` | jump to tab N (the numbers in the strip) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | next / previous tab |
| `Cmd+T` / `Cmd+W` | new / close tab |
| `Cmd+[` / `Cmd+]` | back / forward |
| `Cmd+R` | reload |
| `Cmd+Shift+T` | reopen closed tab |

## Extensions

Extension icons live at the **right end of the tab strip**, like status-bar
items — 22px cells, dimmed when idle, full colour on hover, with badges kept
(uBlock's block count still shows, as a small gold counter).

```
┌──────────────────────────────────────────────────────┐
│ 1 Hacker News  2 Lobsters  3 MDN        ⛊  ▶  🧩     │
├──────────────────────────────────────────────────────┤
```

The rightmost puzzle-piece is the extensions button; clicking it opens the
panel listing **unpinned** extensions. Firefox leaves newly installed
extensions unpinned by default, so a new install appears in that panel rather
than the strip — pin it from the panel's `…` menu to give it a strip cell.

While the address bar is summoned the icons step aside, and return on blur.

Verified against uBlock Origin, Bitwarden and SponsorBlock installed together:
both pinned icons reachable, the unpinned one listed by name, popups opening
on screen, and `Cmd+L` unaffected.

If you want extensions gone entirely, set `--mz-extensions-display: none` and
reach them by keyboard: assign shortcuts in `about:addons` → gear →
**Manage Extension Shortcuts**. uBlock ships `_execute_browser_action` with no
default key, so you can bind its popup to anything.

## Knobs

At the top of `userChrome.css`:

| variable | default | effect |
|---|---|---|
| `--mz-tabs-display` | `flex` | `none` removes the tab strip entirely — zero chrome, `Cmd+1..9` to navigate |
| `--mz-extensions-display` | `flex` | `none` hides extension icons; reach them by keyboard shortcut |
| `--mz-traffic-lights` | `none` | `flex` restores the macOS window buttons |
| `--mz-strip-height` | `22px` | tab strip height |
| `--mz-font` / `--mz-font-size` | Hack Nerd Font Mono / 11.5px | chrome typeface |

Colours are the `--mz-*` block below those; they are ayu dark, taken verbatim
from `~/.local/share/nvim/lazy/neovim-ayu/lua/ayu/colors.lua` (mirage = false).

## What `user.js` does

CSS cannot remove everything. `user.js` pins the prefs that do the rest —
notably `widget.macos.native-context-menus = false`, without which macOS draws
context menus natively and no stylesheet can touch them. It also forces
compact density, a blank new tab, dark chrome, and strips the address bar's
suggestion clutter (quick actions, trending, weather). Each line is commented.

Removing `user.js` stops it *pinning* those values but does not undo the ones
already written into `prefs.js` — reset those in `about:config`.

## Testing without touching your profile

`tools/` drives a throwaway profile at `/tmp/ffmin/profile` over Firefox's
Marionette protocol (no geckodriver, no selenium) and screenshots the chrome:

```sh
python3 tools/shoot.py     # builds a clean profile, writes /tmp/ffmin/*.png
python3 tools/probe.py    # dumps the live chrome DOM with computed styles
```

`screencapture(1)` needs Screen Recording and fails from a terminal, so
Marionette's `WebDriver:TakeScreenshot` in **chrome** context is the only way
to see the UI being styled. That needs the `-remote-allow-system-access` flag
on Firefox 136+.

## Gotchas found while building this

Recorded because each one cost a debugging round-trip:

1. **Never declare `@namespace url(...xul)`.** The usual boilerplate makes
   `:root` and every bare `.class` selector XUL-only, but the chrome document
   is rooted in an HTML element and so are the urlbar results. With it present,
   every custom property silently evaluates to nothing.
2. **The window background is painted on `<body>`**, with a gradient, not on
   any toolbar. Clearing the toolbars alone leaves it showing through.
3. **`isolation: isolate` on `#navigator-toolbox`** is what lets chrome paint
   over the page. `position: relative; z-index: 10` is not enough — the content
   browser composites in its own layer.
4. **Firefox 136+ renamed the urlbar internals.** `#urlbar-background` →
   `.urlbar-background`, `#urlbar-input-container` → `.urlbar-input-container`,
   `#identity-box` → `#trust-icon-container`. Older recipes silently no-op.
5. **The results panel is a top-layer popover**, so it ignores an ancestor's
   `transform`. Centre the overlay with `left: 50%` + a negative margin, or the
   input moves and the panel stays behind.
6. **Tabs default to `flex: 100 100 0%`** and split the window between them.
   A window list needs `flex: 0 0 auto; width: max-content`.
7. **`-moz-box` no longer exists.** `CSS.supports('display','-moz-box')` is
   `false`, so the declaration every old recipe uses is invalid and dropped —
   the element silently stays hidden. Use `flex`.
8. **`opacity: 0` composites the whole subtree**, so a child cannot opt back
   in with any z-index or `position: fixed`. Hiding the nav bar that way made
   the extension icons measure a correct 22x22 and paint nothing at all.
   Collapse to `height: 0` instead and hide only the urlbar container.
9. **Hiding `#unified-extensions-button` strands every extension popup**: it
   is the anchor they hang off, and without it they open off-screen (measured
   at y = -56 and y = -297). Keep it.
10. **`.unified-extensions-item` is used in two places** — toolbar cells and
    panel rows. Style the toolbar ones scoped to
    `#nav-bar-customization-target`, or panel rows collapse to 22x22 squares
    with their names clipped away.
