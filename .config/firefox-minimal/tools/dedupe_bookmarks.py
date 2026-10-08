#!/usr/bin/env python3
"""
Remove duplicated bookmark subtrees from the Bookmarks Toolbar.

Repeated imports stack identical copies. Restoring places.sqlite from a
backup would fix it but also discard browsing history, which lives in the
same database -- so delete the extra copies instead, keeping the first of
each title.

Uses PlacesUtils.bookmarks.remove (removing a folder removes its children),
never raw SQL: places.sqlite has invariants across several tables that a
hand-written DELETE silently breaks.

    python3 tools/dedupe_bookmarks.py --profile <dir> [--apply]

Dry-run by default.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette  # noqa: E402

FIREFOX = "/Applications/Firefox.app/Contents/MacOS/firefox"

SCRIPT = r"""
const cb = arguments[arguments.length - 1];
const apply = arguments[0];
(async () => {
try {
  const { PlacesUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/PlacesUtils.sys.mjs");
  const out = [];

  const tree = await PlacesUtils.promiseBookmarksTree(
    PlacesUtils.bookmarks.toolbarGuid);
  const kids = tree.children || [];
  out.push("toolbar children: " + kids.length);

  // Key on title + type + the set of child URLs, so two genuinely different
  // folders that happen to share a name are not collapsed together.
  const keyOf = (n) => {
    const urls = (n.children || []).map(c => c.uri || c.title).sort().join("|");
    return [n.title || "", n.typeCode, urls].join("\u0000");
  };

  const seen = new Map();
  const doomed = [];
  for (const k of kids) {
    const key = keyOf(k);
    if (seen.has(key)) doomed.push(k);
    else seen.set(key, k);
  }

  out.push("unique: " + seen.size + ", duplicates: " + doomed.length);
  for (const d of doomed) {
    out.push("  would remove: " + (d.title || d.uri)
             + "  (" + ((d.children || []).length) + " child items)");
  }

  if (apply) {
    for (const d of doomed) {
      await PlacesUtils.bookmarks.remove(d.guid);
    }
    await new Promise(r => setTimeout(r, 1500));
    const after = await PlacesUtils.promiseBookmarksTree(
      PlacesUtils.bookmarks.toolbarGuid);
    out.push("REMOVED " + doomed.length);
    out.push("toolbar children now: " + (after.children || []).length);
    for (const c of (after.children || []))
      out.push("   " + (c.typeCode === 2 ? "[folder] " : "         ")
               + (c.title || c.uri));
  }

  const total = (await (await PlacesUtils.promiseDBConnection()).execute(
    "SELECT count(*) AS n FROM moz_bookmarks WHERE type = 1"))[0]
      .getResultByName("n");
  out.push("total bookmarks: " + total);
  cb(out.join("\n"));
} catch (e) { cb("ERR " + e + "\n" + e.stack); }
})();
"""


def profile_in_use(profile):
    """True only on positive evidence that Firefox holds this profile.

    `lsof +D` recurses the whole profile (~124 MB) and can time out; its
    failure path must NOT be read as "in use", or a legitimate run is blocked
    by a slow scan -- which is exactly what happened. Check the lock file
    directly (O(1)) and fall back to the command line of running processes.
    """
    lock = os.path.join(profile, ".parentlock")
    try:
        o = subprocess.run(["lsof", "--", lock], capture_output=True,
                           text=True, timeout=20).stdout
        if any("irefox" in ln for ln in o.splitlines()):
            return True
    except Exception:
        pass  # unknown, not busy
    if subprocess.run(["pgrep", "-f", f"--profile {profile}"],
                      capture_output=True).returncode == 0:
        return True
    return False

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("--apply", action="store_true")
    a = ap.parse_args()

    profile = os.path.expanduser(a.profile)
    if profile_in_use(profile):
        sys.exit("that profile is open in Firefox — quit it first")

    if a.apply:
        bk = os.path.expanduser("~/.local/share/firefox-minimal/"
                                f"places-predupe-{time.strftime('%Y%m%d-%H%M%S')}")
        os.makedirs(bk, exist_ok=True)
        for ext in ("", "-wal", "-shm"):
            s = os.path.join(profile, "places.sqlite" + ext)
            if os.path.exists(s):
                shutil.copy2(s, bk)
        print(f"backed up places.sqlite to {bk}")

    proc = subprocess.Popen(
        [FIREFOX, "--profile", profile, "--marionette",
         "-remote-allow-system-access", "--no-remote", "--new-instance",
         "--headless", "about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        m = Marionette(port=2828, timeout=120)
        m.new_session()
        m.chrome()
        time.sleep(2)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": SCRIPT, "args": [a.apply],
                      "newSandbox": False})["value"])
        time.sleep(2)
        m.quit()
    finally:
        time.sleep(3)
        if proc.poll() is None:
            proc.terminate()
            time.sleep(3)
        if proc.poll() is None:
            proc.kill()


if __name__ == "__main__":
    main()
