# Keyboard reference — minimal Firefox

The chrome has no buttons, so these **are** the interface.

Everything below was dumped from the live keyset
(`document.querySelectorAll('key')`) on Firefox 157 with this config applied,
not recalled from memory. Regenerate after a Firefox update with
`python3 tools/dump_keys.py`.

## Essential

| key | does |
|---|---|
| `Cmd+L` | address bar — the centred prompt |
| `Cmd+T` | new tab |
| `Cmd+W` | close tab |
| `Cmd+Shift+T` | reopen closed tab |
| `Cmd+1` … `Cmd+8` | jump to tab N (the numbers in the strip) |
| `Cmd+9` | jump to **last** tab (not tab 9) |
| `Cmd+[` / `Cmd+]` | back / forward |
| `Cmd+←` / `Cmd+→` | back / forward (same thing) |
| `Cmd+R` | reload |
| `Cmd+.` or `Esc` | stop loading |

Tab cycling — `Ctrl+Tab` / `Ctrl+Shift+Tab` — is implemented in browser code
rather than the keyset, so it does not appear in the dump. `Ctrl+Shift+Tab`
additionally opens the all-tabs panel when `browser.ctrlTab.sortByRecentlyUsed`
is on.

## Finding things

| key | does |
|---|---|
| `Cmd+F` | find in page — the `/` prompt at the bottom |
| `Cmd+G` | next match |
| `Cmd+Shift+G` | previous match |
| `Cmd+E` | find the selected text |
| `Cmd+K` | search (focuses the address bar in search mode) |

## Bookmarks

| key | does |
|---|---|
| `Cmd+Shift+B` | toggle the **second strip** (the folder row) |
| `Cmd+B` | toggle the bookmarks **sidebar** (tree) |
| `Cmd+Shift+O` | the full Bookmarks Library window |
| `Cmd+D` | bookmark this page |
| `Cmd+Shift+D` | bookmark all tabs |

### Navigating the second strip by keyboard

**F6 does not work.** Tested with real keystrokes through the widget layer:
six F6 presses left focus on `browser` every time. It is widely documented as
the chrome-cycling key and it simply does not reach this toolbar on macOS
Firefox 157.

The route that *does* work, measured by reading `document.activeElement`
after each press:

```
Cmd+L         focus the address bar
Tab           -> Extensions button
Tab           -> first bookmark cell       <- you are on the strip
← / →         walk between folders
↓ or Enter    open the focused folder
↑ / ↓         move within the open menu
→             enter a submenu
Enter         open the bookmark
Esc           close the menu / leave the toolbar
```

From a focused page, plain `Tab` x4 gets there too, but the tab order starts
inside the page content so it is not reliable.

The focused cell is reverse-video gold, so the position is always visible.

A single dedicated key (no F-keys, no Tab-walking) is possible but needs
userChrome.js, which means an autoconfig file inside `/Applications/Firefox.app`
— see README, "A real keybind for the bookmark strip".

### Searching bookmarks only

Firefox has urlbar **restriction tokens** — a prefix that scopes the query to
one source. No custom search engine needed:

| token | restricts to |
|---|---|
| `*` | bookmarks |
| `^` | history |
| `%` | open tabs |
| `#` | page titles |
| `$` | URLs |

So `Cmd+L` then `* keymap` searches bookmarks only. Verified: returns
`type=bookmark` results with nothing from history.

The token is a **prefix** — `* keymap`, not `keymap *`.

## Window and view

| key | does |
|---|---|
| `Cmd+N` | new window |
| `Cmd+Shift+P` | private window |
| `Cmd+Shift+W` | close window |
| `Cmd+Ctrl+F` | fullscreen |
| `Cmd+Opt+R` | reader mode |
| `Cmd+Opt+Shift+]` | picture-in-picture |
| `Ctrl+M` | mute the tab |

## Other panels

| key | does |
|---|---|
| `Cmd+Y` | history library |
| `Cmd+Shift+H` | history sidebar |
| `Cmd+J` | downloads |
| `Cmd+Shift+A` | add-ons manager |
| `Cmd+I` | page info |
| `Cmd+Shift+S` | screenshot |
| `Ctrl+Z` | toggle whichever sidebar was last open |
| `Ctrl+U` | open-tabs sidebar |

## Developer

| key | does |
|---|---|
| `Cmd+Opt+I` or `F12` | devtools |
| `Cmd+Shift+J` | browser console |

## Extensions

The icons sit at the right of the tab strip. Extensions can define their own
shortcuts, but most ship none by default — assign them at:

```
about:addons → gear icon → Manage Extension Shortcuts
```

uBlock Origin, for example, declares `_execute_browser_action` with no default
key, so its popup can be bound to anything.
