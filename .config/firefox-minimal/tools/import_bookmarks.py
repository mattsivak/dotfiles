#!/usr/bin/env python3
"""
Import a Netscape bookmark HTML file into a Firefox profile.

    python3 tools/import_bookmarks.py --profile <dir> <file.html>

Uses BookmarkHTMLUtils.importFromFile with `replace: false` — the same code
path as Bookmarks → Import, so existing bookmarks are kept and places.sqlite
is never written by hand (doing that risks corrupting it).

Refuses a profile Firefox has open, and backs up places.sqlite first.
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

IMPORT = r"""
const cb = arguments[arguments.length - 1];
const path = arguments[0];
(async () => {
try {
  const { BookmarkHTMLUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/BookmarkHTMLUtils.sys.mjs");
  const { PlacesUtils } = ChromeUtils.importESModule(
    "resource://gre/modules/PlacesUtils.sys.mjs");

  const before = (await (await PlacesUtils.promiseDBConnection()).execute(
    "SELECT count(*) AS n FROM moz_bookmarks WHERE type = 1"))[0]
      .getResultByName("n");

  await BookmarkHTMLUtils.importFromFile(path, { replace: false });
  await new Promise(r => setTimeout(r, 3000));

  const after = (await (await PlacesUtils.promiseDBConnection()).execute(
    "SELECT count(*) AS n FROM moz_bookmarks WHERE type = 1"))[0]
      .getResultByName("n");

  cb(JSON.stringify({ before, after, added: after - before }));
} catch (e) { cb("ERR " + e); }
})();
"""


def profile_in_use(profile):
    try:
        out = subprocess.run(["lsof", "+D", profile], capture_output=True,
                             text=True, timeout=90).stdout
        if sum(1 for ln in out.splitlines() if "irefox" in ln):
            return True
    except Exception:
        pass
    return subprocess.run(["pgrep", "-f", f"--profile {profile}"],
                          capture_output=True).returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("html")
    a = ap.parse_args()

    profile = os.path.expanduser(a.profile)
    html = os.path.abspath(a.html)
    if not os.path.isdir(profile):
        sys.exit(f"no such profile: {profile}")
    if not os.path.exists(html):
        sys.exit(f"no such file: {html}")

    if profile_in_use(profile):
        sys.exit("that profile is open in Firefox — quit it first")

    stamp = time.strftime("%Y%m%d-%H%M%S")
    bk = os.path.expanduser(
        f"~/.local/share/firefox-minimal/places-backup-{stamp}")
    os.makedirs(bk, exist_ok=True)
    for ext in ("", "-wal", "-shm"):
        src = os.path.join(profile, "places.sqlite" + ext)
        if os.path.exists(src):
            shutil.copy2(src, bk)
    print(f"backed up places.sqlite to {bk}")

    proc = subprocess.Popen(
        [FIREFOX, "--profile", profile, "--marionette",
         "-remote-allow-system-access", "--no-remote", "--new-instance",
         "--headless", "about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"firefox pid {proc.pid} (headless)")
    try:
        m = Marionette(port=2828, timeout=120)
        m.new_session()
        m.chrome()
        time.sleep(2)
        res = m.send("WebDriver:ExecuteAsyncScript",
                     {"script": IMPORT, "args": [html], "newSandbox": False})["value"]
        print(res)
        time.sleep(3)
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
