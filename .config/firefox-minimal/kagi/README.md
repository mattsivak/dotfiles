# kagi — terminal-style search

Companion theme for `../` (the minimal Firefox chrome). Same ayu dark palette,
same Hack Nerd Font Mono, same square-everything rules — so a Kagi tab reads as
a continuation of the browser rather than a web page sitting inside it.

Each result is laid out like a line of program output, under a `tree`-style
guide rule that brightens on hover:

```
 │ koekeishiya/yabai: A tiling window manager for macOS
 │ github.com/koekeishiya/yabai
 │ yabai is a window management utility that gives you control
 │ over your windows. 2 days ago
```

- **Blue** titles, **green** hostnames, dim grey paths, **gold** for matched
  terms and anything active.
- Favicons removed; the hostname already says which site it is.
- Active lens (`search` / `images` / …) is reverse-video gold, exactly like the
  active tab in the browser's strip.
- Instant answers get a gold left bar instead of a card.
- Phone layout at ≤768px: larger type, guide rule dropped to reclaim width.

## Install

1. Open <https://kagi.com/settings?p=custom_css>
   (or Kagi → Settings → Appearance → Custom CSS)
2. Set **Appearance → Theme** to a **dark** variant first — this themes dark
   mode; on light mode Kagi keeps light backgrounds outside these selectors.
3. Paste the contents of [`kagi.css`](kagi.css), toggle **Enable Custom CSS**
   on, and click **Apply**.

```sh
pbcopy < ~/dotfiles/.config/firefox-minimal/kagi/kagi.css
```

Because it lives in your Kagi account, it follows your login everywhere —
including Kagi on your iPhone — with no browser config.

## If something breaks

Append `?no_css` to any Kagi URL to render without it:

```
https://kagi.com/search?q=test&no_css
```

You cannot lock yourself out: Kagi never applies custom CSS to settings pages,
so Appearance stays reachable even if the stylesheet is badly broken.

## Preview without touching your account

```sh
open ~/dotfiles/.config/firefox-minimal/kagi/preview/index.html
```

`preview/index.html` reproduces Kagi's real DOM structure and class names
offline. Kagi's `/search` redirects to `/signin` without a session (verified:
302), so a live SERP can't be rendered from a script — the mock exercises the
same hooks instead.

**It is a preview, not proof.** An element that looks wrong there is a real
bug; an element that looks right is only *probably* right. The live page is the
final word.

## Verification

Validated **against the live SERP**, not only the mock. `tools/kagi_live.py`
and `tools/kagi_diag.py` drive a *copy* of the logged-in scratch profile
(your own window keeps running), load a real results page with `?no_css` to
get Kagi's stock markup, then inject `kagi.css` the same way Kagi's settings
do — so fixes are measured on real results without touching the account.

```sh
python3 ../tools/kagi_live.py --dump      # live DOM structure
python3 ../tools/kagi_diag.py             # defect counts, before/after
```

Current state, measured on the live page:

| check | before | after |
|---|---|---|
| doubled guide rules | 1 nested pair | **0** |
| icon buttons with a border | 68 | **0** |
| nested bordered panels | widgetContent ⊃ widgetItem | **0** |
| headings in Kagi's own face | `h3` = Lufga | **0** (all Hack) |
| URL row height | 29px | 17px |

- `css-tree`: **0 parse errors**, 236 selectors, 0 invalid declarations.
- 20,511 chars of the 40,000 limit (19,489 spare).
- Rendered at 1265px and 430px (iPhone width).

## Selector notes

Kagi's markup moves, and stale selectors fail silently — a rule that matches
nothing is not an error. Current vocabulary, cross-checked against Kagi's
documented list plus two maintained community themes
([kagi-darker 3.0](https://github.com/realrogue/kagi-darker),
[kagi-google-theme](https://github.com/shmublu/kagi-google-theme)):

| element | selector |
|---|---|
| result block | `.search-result`, `._0_SRI`, `.__srgi` (grouped) |
| title / link | `.__sri-title`, `.__sri_title_link`, `.__srgi-title` |
| url parts | `.__sri-url`, `.__sri_url_path_box`, `.host`, `.path` |
| description | `.__sri-desc`, `.__sri-body`, `._0_DESC` |
| freshness | `.__sri-time`, `.--new` |
| search box | `.search-input-container`, `._0_search-input-container` |
| lenses / nav | `.serp-nav`, `.nav_item`, `.--active` |
| instant answer | `.instant-answer`, `.ia-wrapper` |
| favicon | `.__domain-favicon` |

The older `.sri-*` (single underscore) names still appear in places; rules
target both where it is cheap to do so.

### Gotchas found on the live page

1. **`:visited` must precede `:hover`** (LVHA order) or hover wins for links
   you have been to. Firefox also restricts which properties `:visited` may
   set — colour is allowed — and it never shows in a mock, only on real
   history.
2. **The tree guide needs `position: relative` on the result block.** Without
   it the absolutely-positioned rule escapes to the nearest positioned
   ancestor and draws down the entire page.
3. **Grouped results nest**, so `.__srgi` inside `.sri-group` needs its own
   indent or parent and child draw their guides at the same x.
4. **Kagi's own CSS variables do most of the work.** Setting
   `--search-result-title`, `--background-color` and friends at `:root` styles
   far more of the page than element rules, and survives markup changes better.
5. **`.sri-group` WRAPS `.search-result` at identical coordinates**, and
   `.widgetItem` also carries `._0_SRI`. Styling that whole family draws the
   guide rule two or three times over. Exactly one element per result may
   carry it — `.search-result` and `.__srgi`, excluding `.widgetItem`.
6. **Never blanket-border `button`.** Kagi uses `<button>` for 68 icon-only
   controls, two on every result row; they end up boxed. Border text controls
   explicitly and give icon buttons `border: none`.
7. **`.dd-toggle` is a hidden 16x4 checkbox**, not a visible pill. Bordering
   it draws a stray tick beside each filter dropdown.
8. **A `.k_ui_dropdown` is not always a text control** — the per-result "+"
   is one. Scope dropdown framing to the filter bar, and leave the popup list
   (`.k_ui_dropdown_data_list`) framed since it genuinely is a panel.
9. **Frame only the outermost container.** `.widgetContent` contains
   `.widgetItem`; framing both gives "Blast from the Past" a box inside a box.
10. **Headings do not inherit `font-family` from `body`** here — `h3` rendered
    in Kagi's display face (Lufga) until named explicitly.
