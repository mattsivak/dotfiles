#!/usr/bin/env python3
"""
Is "Cmd+L, Tab, Tab" a STABLE route to the bookmarks strip?

The macro replays keystrokes, so it breaks silently if the number of tab stops
between the urlbar and the bookmarks toolbar changes with the number of pinned
extensions. Firefox defines those stops with explicit <toolbartabstop>
elements, so count them rather than assuming.

Tested with 0, 1 and 3 pinned extensions.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

XPIS = ["/tmp/ublock-origin.xpi", "/tmp/sponsorblock.xpi",
        "/tmp/bitwarden-password-manager.xpi"]

SETUP = r"""
const cb = arguments[arguments.length - 1];
(async () => {
  const { BookmarkHTMLUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/BookmarkHTMLUtils.sys.mjs");
  const { PlacesUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/PlacesUtils.sys.mjs");
  await BookmarkHTMLUtils.importFromFile("/tmp/helium-bookmarks.html",
                                         { replace: false });
  await new Promise(r => setTimeout(r, 3000));
  const tree = await PlacesUtils.promiseBookmarksTree(
    PlacesUtils.bookmarks.menuGuid);
  for (const c of (tree.children || [])) {
    if (!/^bookmarks? toolbar$/i.test(c.title || "")) continue;
    for (const g of (c.children || []))
      await PlacesUtils.bookmarks.update({
        guid: g.guid, parentGuid: PlacesUtils.bookmarks.toolbarGuid,
        index: PlacesUtils.bookmarks.DEFAULT_INDEX });
  }
  await new Promise(r => setTimeout(r, 2500));
  cb("ok");
})();
"""

INSPECT = r"""
const nm = n => n.localName + (n.id ? '#' + n.id : '');
let out = [];
const pinned = document.querySelectorAll(
  '#nav-bar-customization-target .unified-extensions-item').length;
out.push('pinned extensions: ' + pinned);

// Firefox marks keyboard tab stops with explicit <toolbartabstop> elements.
const stops = [...document.querySelectorAll('toolbartabstop')];
out.push('toolbartabstop elements: ' + stops.length);
stops.forEach(s => out.push('   in ' + nm(s.parentElement)
  + '  visible=' + !!(s.getBoundingClientRect().width
                      || s.parentElement.getBoundingClientRect().width)));

const cells = document.querySelectorAll(
  '#PlacesToolbarItems > .bookmark-item').length;
out.push('bookmark cells: ' + cells);
return out.join('\n');
"""

WHO = """
const a = document.activeElement;
return a ? ((a.getAttribute && a.getAttribute('label')) || a.id || a.localName)
         : 'none';
"""

CMD, TAB = "\ue03d", "\ue004"


def press(m, seq):
    acts = []
    for v in seq:
        acts.append({"type": "keyDown", "value": v})
    for v in reversed(seq):
        acts.append({"type": "keyUp", "value": v})
    m.send("WebDriver:PerformActions",
           {"actions": [{"type": "key", "id": "kb", "actions": acts}]})
    time.sleep(0.5)


def run(n_ext):
    proc = launch(build_profile(), 1300, 850)
    try:
        m = Marionette()
        m.new_session()
        for x in XPIS[:n_ext]:
            if os.path.exists(x):
                m.send("Addon:Install", {"path": x, "temporary": False})
                time.sleep(2)
        time.sleep(3)
        m.chrome()
        m.send("WebDriver:ExecuteAsyncScript",
               {"script": SETUP, "args": [], "newSandbox": False})
        print(m.script(INSPECT))

        m.script("gURLBar.blur(); gBrowser.selectedBrowser.focus();")
        time.sleep(0.5)
        press(m, [CMD, "l"])
        trail = [m.script(WHO)]
        for _ in range(3):
            press(m, [TAB])
            trail.append(m.script(WHO))
        print("  Cmd+L then Tabs: " + " -> ".join(trail))

        # how many Tabs to reach the first bookmark cell?
        labels = [c.get("label") for c in [{}]]
        first = m.script("""
          const c = document.querySelector('#PlacesToolbarItems > .bookmark-item');
          return c ? c.getAttribute('label') : null;""")
        hops = trail.index(first) if first in trail else -1
        print(f"  first cell = {first!r}; reached after {hops} Tab(s)"
              if hops >= 0 else f"  first cell {first!r} NOT reached in 3 Tabs")
        m.quit()
        return hops
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()
        time.sleep(1)


if __name__ == "__main__":
    results = {}
    for n in (0, 1, 3):
        print(f"=== {n} pinned extension(s) ===")
        results[n] = run(n)
        print()
    print("hops per extension count:", results)
    print("STABLE" if len(set(results.values())) == 1 and -1 not in results.values()
          else "UNSTABLE — a fixed Tab count would break")
