#!/usr/bin/env python3
"""
Compare ONE element subtree, stock vs ours, flagging every border we add.

Written because three rounds of "fix the thing I can see" kept introducing new
boxes: a broad rule lands on a Kagi element that is already styled, and the
only way to know which side is at fault is to diff against stock.
"""
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, launch  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
CSS = os.path.join(HERE, "..", "kagi", "kagi.css")
LIVE = os.path.expanduser("~/.local/share/firefox-minimal/try-profile")
WORK = "/tmp/kagi-inspect"

TARGETS = [
    ".k_ui_toggle_switch",
]


def make_copy():
    os.makedirs(WORK, exist_ok=True)
    subprocess.run(["rsync", "-a", "--delete",
                    "--exclude", "cache2", "--exclude", "startupCache",
                    "--exclude", "shader-cache", "--exclude", "*.sqlite-wal",
                    LIVE + "/", WORK + "/"], check=True)
    with open(os.path.join(WORK, "user.js"), "a") as f:
        f.write('user_pref("marionette.port", 2830);\n'
                'user_pref("marionette.enabled", true);\n')
    return WORK


SNAP = r"""
const cb = arguments[arguments.length - 1];
const targets = arguments[0];
(async () => {
try {
  const nm = n => n.localName + (n.id ? '#' + n.id : '')
    + (n.className && typeof n.className === 'string' && n.className.trim()
       ? '.' + n.className.trim().split(/\s+/).join('.') : '');
  const snap = {};
  for (const sel of targets) {
    const root = document.querySelector(sel);
    if (!root) { snap[sel] = null; continue; }
    const rows = [];
    const walk = (n, d) => {
      if (d > 4) return;
      const c = getComputedStyle(n);
      if (c.display === 'none') return;
      const r = n.getBoundingClientRect();
      rows.push({
        k: '  '.repeat(d) + nm(n),
        box: Math.round(r.width) + 'x' + Math.round(r.height),
        bd: c.borderTopWidth + '|' + c.borderLeftWidth,
        bc: c.borderTopColor.replace(/\s/g, ''),
        bg: c.backgroundColor.replace(/\s/g, ''),
        pad: c.padding.replace(/\s+/g, ','),
        rad: c.borderRadius,
      });
      // Pseudo-elements: a toggle knob is almost always ::before/::after.
      for (const pe of ['::before', '::after']) {
        const pc = getComputedStyle(n, pe);
        if (pc.content && pc.content !== 'none') {
          rows.push({
            k: '  '.repeat(d + 1) + pe,
            box: pc.width + 'x' + pc.height,
            bd: pc.borderTopWidth + '|' + pc.borderLeftWidth,
            bc: pc.borderTopColor.replace(/\s/g, ''),
            bg: pc.backgroundColor.replace(/\s/g, ''),
            pad: pc.padding.replace(/\s+/g, ','),
            rad: pc.borderRadius,
          });
        }
      }
      for (const ch of n.children) walk(ch, d + 1);
    };
    walk(root, 0);
    snap[sel] = rows;
  }
  cb(JSON.stringify(snap));
} catch (e) { cb('ERR ' + e); }
})();
"""

INJECT = r"""
const cb = arguments[arguments.length - 1];
document.querySelectorAll('style[data-mz]').forEach(s => s.remove());
const s = document.createElement('style');
s.setAttribute('data-mz','1'); s.textContent = arguments[0];
document.head.appendChild(s);
setTimeout(() => cb('ok'), 1200);
"""


def main():
    proc = launch(make_copy(), 1850, 1200)
    try:
        m = Marionette(port=2830)
        m.new_session()
        m.content()
        m.navigate("https://kagi.com/search?q=test&no_css")
        time.sleep(7)
        if m.script("return /signin/i.test(location.pathname);"):
            print("signed out")
            return

        stock = json.loads(m.send("WebDriver:ExecuteAsyncScript",
            {"script": SNAP, "args": [TARGETS], "newSandbox": False})["value"])
        m.send("WebDriver:ExecuteAsyncScript",
               {"script": INJECT, "args": [open(CSS).read()], "newSandbox": False})
        ours = json.loads(m.send("WebDriver:ExecuteAsyncScript",
            {"script": SNAP, "args": [TARGETS], "newSandbox": False})["value"])

        for sel in TARGETS:
            print("=" * 78)
            print(sel)
            a, b = stock.get(sel), ours.get(sel)
            if not a:
                print("  (absent)")
                continue
            for i, row in enumerate(a):
                o = b[i] if b and i < len(b) else None
                if not o:
                    print("  " + row["k"] + "  <missing in ours>")
                    continue
                added = row["bd"].startswith("0px") and not o["bd"].startswith("0px")
                print("  {:<50} {:>9}{}".format(
                    row["k"], row["box"], "   <<< WE ADD A BORDER" if added else ""))
                for f, label in [("bd", "border"), ("bg", "bg"), ("pad", "pad"),
                                 ("box", "size"), ("rad", "radius")]:
                    if row[f] != o[f]:
                        print("       {}: {} -> {}".format(label, row[f], o[f]))
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
