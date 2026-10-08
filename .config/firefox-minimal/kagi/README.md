# kagi — terminal chrome, readable body

Companion theme for `../` (the minimal Firefox chrome), sharing its ayu dark
palette and square-everything rules so a Kagi tab reads as a continuation of
the browser rather than a web page sitting inside it.

Where it deliberately parts company with the chrome: **prose is not
monospace.**

## The typography model

| | face | used for |
|---|---|---|
| **Sans** (`-apple-system`) | reading | result titles, descriptions, right-rail prose, widget card titles |
| **Mono** (Hack Nerd Font Mono) | machinery | URLs, nav, filter pills, result counts, timestamps, buttons |

The earlier all-mono version looked right in a screenshot and read badly in
use. Monospace has no shape variety and a small x-height, so a 12px
description renders as grey texture rather than a sentence. The terminal
character lives in the *machinery* — that all stays mono.

Supporting rules, each of which mattered more than any colour choice:

- **Hierarchy is carried by size, never by opacity.** Titles 16px, descriptions
  14.5px, URLs 12px. The old 13 / 12 / 11.5 ramp was one pixel apart, which is
  no hierarchy at all — nothing told the eye where a result began.
- **Every readable tier clears 4.5:1** against the background. A `--mz-faint`
  tier sits below that and is used only for decoration, never for a word you
  have to read.
- **Each result sits on a subtle card** (`#0f131a` on a `#0b0e14` page) with a
  2px left edge that turns gold on hover. Barely lifted — enough to give a
  result edges, not enough to turn 25 of them into luggage.
- Grouped same-site hits keep their hierarchy: the parent gets the card, its
  children stay transparent and indented beneath it.

Unchanged from the original: blue titles, green hostnames, gold for matched
terms and anything active; favicons removed; active lens in reverse-video
gold; instant answers marked with a gold left bar rather than a card.

## Install

1. Open <https://kagi.com/settings?p=custom_css>
   (or Kagi → Settings → Appearance → Custom CSS)
2. Set **Appearance → Theme** to a **dark** variant first — this themes dark
   mode; on light mode Kagi keeps light backgrounds outside these selectors.
3. Paste the contents of [`kagi.css`](kagi.css), toggle **Enable Custom CSS**
   on, and click **Save Changes**.

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

## Verification

Validated **against the live SERP**, not a mock. The loop that works:

```sh
ego-browser nodejs -e '
const task = await taskSpace("kagi css");
const page = task.page("p1");
await page.goto("https://kagi.com/search?q=...&no_css");   // stock markup
await page.waitForSelector("loc=css:.__sri-desc", { state: "visible" });
await page.waitForTimeout(2500);                            // results stream in
const stock = await page.evaluate(probe);
await page.evaluate((t) => {                                // inject as Kagi does
  const s = document.createElement("style"); s.textContent = t;
  document.head.appendChild(s);
}, css);
const ours = await page.evaluate(probe);                    // then diff in Node
'
```

**Build the stock-vs-ours diff before the first fix.** Both regressions below
were invisible in a screenshot and obvious in one diff. Three rounds of fixing
what looked wrong in a screenshot each introduced new damage.

Mobile needs no second browser:
`page.cdp("Emulation.setDeviceMetricsOverride", {width:393, height:852, deviceScaleFactor:3, mobile:true})`.

Current state, measured on the live page:

| check | value |
|---|---|
| header height | 127px (stock 126px) |
| results column | 760px (stock 700px, broken intermediate 495px) |
| title / desc / url | 16 / 14.5 / 12px, sans / sans / mono |
| description opacity | 1 (was 0.85) |
| grouped children | indented to x=219 under a parent at x=194 |
| widget + video cards | correctly excluded from the card treatment |
| iPhone 393px | no horizontal overflow |

- `css-tree`: **0 parse errors**.
- 27,970 chars of the 40,000 limit (12,030 spare). Note Kagi counts
  *characters*, not bytes — the file is 28,056 bytes because of em dashes in
  the comments.

`preview/index.html` and `../tools/kagi_*.py` are the older offline-mock and
Marionette-profile-copy workflow. They still work, but the ego-browser loop
above replaces them: it drives an already-logged-in browser, so no profile
copying and no mock fidelity problem.

## Selector notes

Kagi's markup moves, and stale selectors fail silently — a rule that matches
nothing is not an error. Cross-checked against Kagi's documented list plus two
maintained community themes
([kagi-darker 3.0](https://github.com/realrogue/kagi-darker),
[kagi-google-theme](https://github.com/shmublu/kagi-google-theme)):

| element | selector |
|---|---|
| result block | `.search-result`, `._0_SRI`, `.__srgi` (grouped) |
| group wrapper | `.sri-group`, `.sr-group` |
| title / link | `.__sri-title`, `.__sri_title_link`, `.__srgi-title` |
| url parts | `.__sri-url`, `.__sri_url_path_box`, `.host`, `.path` |
| description | `.__sri-desc`, `.__sri-body`, `._0_DESC` |
| freshness | `.__sri-time`, `.--new` |
| search box | `.search-input-container`, `._0_search-input-container` |
| lenses / nav | `.serp-nav`, `.nav_item`, `.--active` |
| filter pills | `.filter-item`, `.dd-toggle-label` |
| widget cards | `.widgetContent`, `.widgetItem`, `.widget-body`, `.videoResultTitle` |
| instant answer | `.instant-answer`, `.ia-wrapper` |
| favicon | `.__domain-favicon` |
| settings textarea | `#_0_custom_css_textarea`, `#settings_custom_css_enabled` |

The older `.sri-*` (single underscore) names still appear in places; rules
target both where it is cheap to do so.

### Layout gotchas

1. **`.center-content-box` and `.app-content-box` are not content-area
   classes.** The page header carries `.app-content-box`, and the header and
   top-panel each contain their own `.center-content-box`. Putting `flex` or
   `max-width` on those names reflowed the header from 126px to **831px tall**
   — roughly 700px of blank space above the first result. Scope layout rules to
   `main#main` and `#_0_app_content`.
2. **Do not cap `#_0_app_content`.** It is the flex *row* holding `<main>` plus
   a 500px `.right-content-box`. Capping it at 1100px starved main to **495px,
   narrower than Kagi's stock 680px**. Stock already lays out a 1550px row, so
   widening main needs only `--center_content_width` plus a basis on
   `main#main`; the row needs no change.
3. **Prose wants ~75 characters per line**, not the full window. 760px at
   14.5px sans is the useful target; "fill the window" is the wrong goal.
4. **Kagi's own CSS variables do most of the work.** Setting
   `--search-result-title`, `--background-color` and friends at `:root` styles
   far more of the page than element rules, and survives markup changes better.

### Control gotchas

5. **Recolour only — Kagi owns the geometry.** Adding padding and min-height to
   `.filter-item` grew the pills from 199x32 to 240x36 and wrapped the row;
   bordering `.more_search_dropdown_box` turned a 24x30 icon into a 51x77 empty
   box beside the kebab.
6. **…except that a font swap changes metrics.** `.dd-toggle-label` has an
   explicit 16.8px that does **not** inherit from the pill, so switching it to
   mono widened every pill (199→226, 135→157), wrapped the row, and stretched
   `.more_search_dropdown_box` to 24x69. Size the label, not just the pill.
   (On a narrow window the filter row wraps in *stock* Kagi too — diff before
   calling it a regression.)
7. **Never blanket-border `button`.** Kagi uses `<button>` for 68 icon-only
   controls, two on every result row; they all end up boxed.
8. **`.dd-toggle` is a hidden 16x4 checkbox**, not a visible pill. Bordering it
   draws a stray tick beside each filter dropdown.
9. **A `.k_ui_dropdown` is not always a text control** — the per-result "+" is
   one. Scope dropdown framing to the filter bar, and leave the popup list
   (`.k_ui_dropdown_data_list`) framed since it genuinely is a panel.
10. **Shape carries meaning.** A blanket `* { border-radius: 0 }` squares the
    lens toggle (`.k_ui_toggle_switch`, a 26x16 pill) into a box inside a box.
    And an exception list of *elements* does not cover their pseudo-elements —
    the knob is `.k_ui_toggle_switch_bar::after` and needs naming separately.

### Result-block gotchas

11. **`.sri-group` WRAPS `.search-result` at identical coordinates**, and
    `.widgetItem` also carries `._0_SRI`. Decorating that whole family draws
    the treatment two or three times over. Exactly one element per result:
    `.search-result` and `.__srgi`, excluding `.widgetItem`.
12. **One card rule for every result flattens grouped results.** Kagi groups
    same-site hits as a `.search-result` parent followed by `.__srgi` children
    inside a `.sri-group`; an identical card put all five at the same x and
    width, so a parent and its four sub-pages read as five unrelated results.
    Fill the parent only, keep children transparent and indented, and put the
    inter-result margin on the group so it reads as one unit.
13. **Video and news cards have their own title classes.** `.widget-body` and
    `.videoResultTitle` are reached by none of the result-title selectors, so
    they sat at the inherited 19.2px mono — the loudest, worst-reading text on
    the page.
14. **Frame only the outermost container.** `.widgetContent` contains
    `.widgetItem`; framing both gives "Blast from the Past" a box inside a box.
15. **Headings do not inherit `font-family` from `body`** here — `h3` rendered
    in Kagi's display face (Lufga) until named explicitly.
16. **`:visited` must precede `:hover`** (LVHA order) or hover wins for links
    you have been to. Firefox also restricts which properties `:visited` may
    set — colour is allowed — and it never shows in a mock, only on real
    history.
