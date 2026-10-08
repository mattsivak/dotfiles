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

## Try it / Install

Two separate things. **Trying** it runs a second Firefox with its own profile,
beside your real one. **Installing** applies the chrome to your real profile.

```sh
./try.sh                 # open the scratch profile (keeps its extensions)
./try.sh --fresh         # wipe and start clean (prompts if extensions exist)
./try.sh --promote       # copy the scratch profile to a permanent one
```

```sh
./install.sh --dry-run     # see exactly what it will touch
./install.sh               # back up, then install into default-release
./install.sh --uninstall   # restore the backup
```

### Where the scratch profile lives — and why not /tmp

`~/.local/share/firefox-minimal/try-profile`

Not `/tmp`: macOS prunes it, so extensions and their configuration would
disappear on reboot. If you set up extensions in the scratch profile, that
work lives only there — this repo holds CSS and scripts, never profile data
(it contains cookies, logins and session tokens).

So back it up:

```sh
./backup.sh                      # timestamped snapshot
./backup.sh --list
./backup.sh --restore 20261007-182317
./backup.sh --prune 5            # keep newest 5
```

Snapshots go to `~/.local/share/firefox-minimal/snapshots/` (~340 MB each with
a few extensions installed). `--restore` parks the current profile rather than
deleting it, and refuses to run while Firefox has the profile open.

### Moving extensions to your real profile

Extensions do **not** transfer by copying files between profiles — Firefox
keys them to the profile that installed them. Install them normally in
whichever profile you intend to keep, then sign in to each one again.

It writes only `<profile>/chrome/` and `<profile>/user.js`, backing up any
existing copies to `chrome.backup-<timestamp>` first. Quit Firefox before
installing: it rewrites `prefs.js` on exit and will clobber a live edit.

## Keys

Since the buttons are gone, these are the whole interface:

| key | does |
|---|---|
| `Cmd+L` | address bar / search prompt |
| `Cmd+F` | find in page |
| `Cmd+1`…`8` | jump to tab N (the numbers in the strip) |
| `Cmd+9` | jump to the **last** tab (not tab 9) |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | next / previous tab |
| `Cmd+T` / `Cmd+W` | new / close tab |
| `Cmd+[` / `Cmd+]` | back / forward |
| `Cmd+R` | reload |
| `Cmd+Shift+T` | reopen closed tab |

Bookmarks:

| key | does |
|---|---|
| `meh - g` / `fn - g` | focus the bookmarks strip (skhd, external / internal keyboard) |
| `Cmd+Shift+B` | toggle the bookmarks strip |
| `Cmd+B` | bookmarks sidebar |
| `Cmd+D` | bookmark this page |
| `Cmd+L` then `* query` | search **bookmarks only** |

`*` is one of five address-bar restriction tokens, and they are **prefixes**
(`* keymap`, not `keymap *`): `*` bookmarks, `^` history, `%` open tabs,
`#` titles, `$` URLs.

Full generated keymap: `SHORTCUTS.md` — regenerate with
`python3 tools/dump_keys.py` after a Firefox update.

**`F6` does not focus the bookmarks toolbar**, despite what every guide says;
measured with real keystrokes, focus never leaves the page. The native route
is `Cmd+L` then `Tab` twice, which is what the skhd chord replays.

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

## Bookmarks

A second 22px strip under the tab list, one cell per folder:

```
┌──────────────────────────────────────────────────────┐
│ 1 Hacker News  2 Lobsters               ⛊  🧩        │
├──────────────────────────────────────────────────────┤
│ Hermes  Work  Random  Keyboards                      │
├──────────────────────────────────────────────────────┤
```

Folders bright, loose bookmarks dimmed, no favicons, reverse-video gold on the
focused cell. `meh - g` (or `fn - g`) jumps to it, then arrows walk the
folders, `Down`/`Enter` opens one, `Esc` leaves.

### Importing from a Chromium browser

```sh
python3 tools/chromium_bookmarks_to_html.py \
  --browser helium -o helium-bookmarks.html
python3 tools/import_bookmarks.py --profile <profile> helium-bookmarks.html
```

Works for Chrome, Brave, Edge, Vivaldi and Helium. `javascript:`/`data:`
bookmarklets are skipped rather than carried across silently.

**Importing is not idempotent** — running it twice stacks a second copy of
everything (9 bookmarks became 18 here). The script reports `before`/`after`
counts so you can see it; if duplicates do appear:

```sh
python3 tools/dedupe_bookmarks.py --profile <profile>           # dry run
python3 tools/dedupe_bookmarks.py --profile <profile> --apply
```

It de-duplicates rather than restoring `places.sqlite` from a backup, because
browsing history lives in the same database and a restore would discard it.

Firefox's own importer ignores `PERSONAL_TOOLBAR_FOLDER="true"` even when
correctly placed — it creates an ordinary folder *named* "Bookmarks Toolbar"
under the menu — so `import_bookmarks.py` relocates those children onto the
real toolbar root afterwards.

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
11. **An id→class rename is the worst kind**, because the old selector stays
    valid and matches nothing. Two bit this config: `.urlbar-go-button` (a
    class on an `<img>`, and it only appears once autofill completes a URL, so
    it survives casual inspection) and `#identity-box`, which still exists
    alongside `#trust-icon-container` and expands to a 180px
    "Extension (moz-extension://…)" label inside the prompt.
12. **`SidebarUI` is now `SidebarController`** (Firefox 136+), and
    `MOZ_MARIONETTE_PORT` is ignored — the port comes from the
    `marionette.port` pref.
13. **The sidebar search field cannot be un-rounded from CSS.** `input#input`
    lives in `moz-input-search`'s shadow root with no exported part; its own
    sheet reads `var(--input-text-border-radius)`, and that variable *resolves
    to 0* while the used value stays `9999px`. Only an `adoptedStyleSheet`
    injected into the shadow root works, which needs userChrome.js.
14. **`lsof +D <profile>` recurses the whole 124 MB profile** and can time out;
    treating that as "in use" blocks a legitimate install. Check
    `.parentlock` directly instead — and note it survives an unclean exit, so
    its mere existence proves nothing.
15. **Verify focus claims with real keystrokes.** `gBrowser.addTab()` reports
    `urlbarFocused: false` where a real `Cmd+T` gives `true`, because the JS
    path skips the focus logic. `Cmd+T` already opens the search prompt
    focused — no binding needed.
