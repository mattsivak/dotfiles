#!/usr/bin/env python3
"""
Verify the bookmarks toolbar as a second strip:
  - folders land ON the toolbar (not in "Other Bookmarks")
  - it renders as one 22px row under the tab strip
  - LEFT/RIGHT arrow between folders, DOWN opens one
  - the sidebar search field is no longer a pill
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

HTML = "/tmp/helium-bookmarks.html"

JS = r"""
const cb = arguments[arguments.length - 1];
const path = arguments[0];
(async () => {
try {
  const { BookmarkHTMLUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/BookmarkHTMLUtils.sys.mjs");
  const { PlacesUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/PlacesUtils.sys.mjs");
  await BookmarkHTMLUtils.importFromFile(path, { replace: false });
  await new Promise(r => setTimeout(r, 3500));

  // Same post-import move the real importer does: PERSONAL_TOOLBAR_FOLDER is
  // not honoured, so relocate the placeholder folder's children.
  const tree = await PlacesUtils.promiseBookmarksTree(
    PlacesUtils.bookmarks.menuGuid);
  for (const child of (tree.children || [])) {
    if (!/^bookmarks? toolbar$/i.test(child.title || "")) continue;
    for (const g of (child.children || [])) {
      await PlacesUtils.bookmarks.update({
        guid: g.guid,
        parentGuid: PlacesUtils.bookmarks.toolbarGuid,
        index: PlacesUtils.bookmarks.DEFAULT_INDEX,
      });
    }
    const fresh = await PlacesUtils.promiseBookmarksTree(child.guid);
    if (!fresh.children || !fresh.children.length)
      await PlacesUtils.bookmarks.remove(child.guid);
  }
  await new Promise(r => setTimeout(r, 2500));

  let out = [];
  const R = e => { const b = e.getBoundingClientRect();
    return `${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}`; };

  // --- did they land on the TOOLBAR root? -------------------------------
  const tb = await PlacesUtils.bookmarks.fetch(
    { parentGuid: PlacesUtils.bookmarks.toolbarGuid, index: 0 });
  const db = await PlacesUtils.promiseDBConnection();
  const kids = await db.execute(
    `SELECT b.title, b.type FROM moz_bookmarks b
       JOIN moz_bookmarks p ON b.parent = p.id
      WHERE p.guid = 'toolbar_____' ORDER BY b.position`);
  out.push("items directly on the Bookmarks Toolbar: " + kids.length);
  kids.forEach(k => out.push("   " + (k.getResultByName("type") === 2
      ? "[folder] " : "         ") + k.getResultByName("title")));

  // --- is the strip rendered? -------------------------------------------
  const bar = document.querySelector("#PersonalToolbar");
  await new Promise(r => setTimeout(r, 1500));
  const c = getComputedStyle(bar);
  out.push("");
  out.push(`#PersonalToolbar ${R(bar)} display=${c.display} bg=${c.backgroundColor}`);

  const items = [...document.querySelectorAll("#PlacesToolbarItems > .bookmark-item")];
  out.push("cells rendered: " + items.length);
  items.forEach(i => out.push(`   "${i.getAttribute("label")}" ${R(i)}`
      + ` container=${i.hasAttribute("container")}`));

  // --- keyboard: focus the toolbar and arrow along it --------------------
  out.push("");
  if (items.length) {
    items[0].focus();
    await new Promise(r => setTimeout(r, 400));
    out.push("after focus(): active = " + (document.activeElement
             ? (document.activeElement.getAttribute("label")
                || document.activeElement.id || document.activeElement.localName)
             : "none"));
    // synthesize a RIGHT arrow the way the real keyboard would
    const util = window.windowUtils;
    const send = (key) => {
      const ev = new KeyboardEvent("keydown",
        { key, code: key, bubbles: true, cancelable: true });
      document.activeElement.dispatchEvent(ev);
    };
    send("ArrowRight");
    await new Promise(r => setTimeout(r, 500));
    out.push("after ArrowRight: active = " + (document.activeElement
             ? (document.activeElement.getAttribute("label")
                || document.activeElement.id) : "none"));
  }

  // --- sidebar search pill ----------------------------------------------
  const SB = window.SidebarController || window.SidebarUI;
  await SB.show("viewBookmarksSidebar");
  await new Promise(r => setTimeout(r, 2500));
  const doc = document.querySelector("#sidebar").contentDocument;
  const host = doc && doc.querySelector("moz-input-search");
  const inp = host && host.shadowRoot && host.shadowRoot.querySelector("input");
  out.push("");
  out.push("sidebar search input border-radius: "
           + (inp ? getComputedStyle(inp).borderRadius : "not found"));

  cb(out.join("\n"));
} catch (e) { cb("ERR " + e + "\n" + e.stack); }
})();
"""


def main():
    proc = launch(build_profile(), 1300, 900)
    try:
        m = Marionette()
        m.new_session()
        m.chrome()
        time.sleep(2)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS, "args": [HTML], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/bookmark-bar.png")
        print("\n/tmp/ffmin/bookmark-bar.png")
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
