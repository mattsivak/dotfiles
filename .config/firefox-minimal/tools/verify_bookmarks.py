#!/usr/bin/env python3
"""
Verify the bookmark workflow end to end in a throwaway profile:

  1. import the generated Netscape HTML via Firefox's own importer
  2. confirm every bookmark and folder landed
  3. confirm `*` in the urlbar restricts results to bookmarks only
  4. confirm the bookmarks sidebar opens and is keyboard-focusable

Uses BookmarkHTMLUtils (the code behind Import from HTML), not a hand-written
places.sqlite poke -- writing that DB directly risks corrupting it.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

HTML = "/tmp/helium-bookmarks.html"

IMPORT = r"""
const cb = arguments[arguments.length - 1];
const path = arguments[0];
(async () => {
try {
  const { BookmarkHTMLUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/BookmarkHTMLUtils.sys.mjs");
  await BookmarkHTMLUtils.importFromFile(path, { replace: false });
  await new Promise(r => setTimeout(r, 2500));
  cb("imported");
} catch (e) { cb("ERR " + e); }
})();
"""

VERIFY = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  const { PlacesUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/PlacesUtils.sys.mjs");
  let out = [];

  // --- 1. what is in the database ---------------------------------------
  const db = await PlacesUtils.promiseDBConnection();
  const rows = await db.execute(
    `SELECT b.title, p.url FROM moz_bookmarks b
       JOIN moz_places p ON b.fk = p.id
      WHERE b.type = 1 ORDER BY b.title`);
  out.push("bookmarks in database: " + rows.length);
  rows.forEach(r => out.push("   " + (r.getResultByName("title") || "(untitled)")));

  const folders = await db.execute(
    `SELECT title FROM moz_bookmarks WHERE type = 2 AND title IS NOT NULL
       AND title != '' ORDER BY title`);
  out.push("folders: " + folders.map(f => f.getResultByName("title")).join(", "));

  // --- 2. bookmark-restricted search ------------------------------------
  // `*` is Firefox's restriction token for bookmarks. UrlbarTokenizer is not
  // a chrome global, so read it from its module rather than assuming.
  let token = "*";
  try {
    const { UrlbarTokenizer } = ChromeUtils.importESModule(
      "resource:///modules/UrlbarTokenizer.sys.mjs");
    token = UrlbarTokenizer.RESTRICT.BOOKMARK;
  } catch (e) { out.push("(token module unavailable: " + e + ")"); }
  out.push("");
  out.push("bookmark restriction token: '" + token + "'");

  gURLBar.focus();
  gURLBar.value = token + " keymap";
  gURLBar.startQuery({ searchString: token + " keymap", allowAutofill: false });
  await new Promise(r => setTimeout(r, 2500));

  const results = [...document.querySelectorAll(".urlbarView-row")];
  out.push("results for '" + token + " keymap': " + results.length);
  results.slice(0, 6).forEach(r => {
    const t = r.querySelector(".urlbarView-title");
    const u = r.querySelector(".urlbarView-url");
    out.push("   type=" + (r.getAttribute("type") || "?")
             + "  " + (t ? t.textContent.trim().slice(0, 40) : "")
             + "  " + (u ? u.textContent.trim().slice(0, 40) : ""));
  });
  const kinds = new Set(results.map(r => r.getAttribute("type")));
  out.push("result types present: " + [...kinds].join(", "));

  gURLBar.blur();
  await new Promise(r => setTimeout(r, 500));

  // --- 3. sidebar -------------------------------------------------------
  out.push("");
  // SidebarUI was renamed SidebarController in Firefox 136+; the old name is
  // undefined and throws. Resolve whichever this build exposes.
  const SB = window.SidebarController || window.SidebarUI;
  out.push("sidebar api: " + (window.SidebarController ? "SidebarController"
                              : window.SidebarUI ? "SidebarUI" : "NONE"));
  await SB.show("viewBookmarksSidebar");
  await new Promise(r => setTimeout(r, 2500));
  const box = document.querySelector("#sidebar-box");
  const r = box.getBoundingClientRect();
  out.push("sidebar: visible=" + SB.isOpen
           + " " + Math.round(r.width) + "x" + Math.round(r.height)
           + " current=" + SB.currentID);

  // the tree inside it, in the sidebar's own document
  const doc = document.querySelector("#sidebar").contentDocument;
  const tree = doc && doc.querySelector("#bookmarks-view");
  if (tree) {
    out.push("tree rows: " + tree.view.rowCount);
    tree.focus();
    await new Promise(r2 => setTimeout(r2, 400));
    out.push("tree focused: " + (doc.activeElement === tree));
  } else {
    out.push("tree: NOT FOUND");
  }
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
                     {"script": IMPORT, "args": [HTML], "newSandbox": False})["value"])
        time.sleep(2)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": VERIFY, "args": [], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/bookmarks-sidebar.png")
        print("\n/tmp/ffmin/bookmarks-sidebar.png")
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
