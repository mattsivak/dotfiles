#!/usr/bin/env python3
"""
Verify the extension strip against THREE real extensions, with pixel proof.

Geometry alone proved misleading once already: the icons measured a correct
22x22 and painted a perfectly flat background, because `opacity: 0` on an
ancestor composites the whole subtree away. So every check here ends in a
real pixel sample of the rendered PNG, not a getBoundingClientRect().
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
XPIS = ["/tmp/ublock-origin.xpi",
        "/tmp/bitwarden-password-manager.xpi",
        "/tmp/sponsorblock.xpi"]

JS = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  let out = [];
  const win = {w: window.innerWidth, h: window.innerHeight};
  const R = e => { const b = e.getBoundingClientRect();
    return `${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}`; };
  const onScreen = e => { const b = e.getBoundingClientRect();
    return b.x >= -1 && b.y >= -1 && b.right <= win.w + 2 && b.bottom <= win.h + 2
           && b.width > 0 && b.height > 0; };
  const hit = e => { const b = e.getBoundingClientRect();
    const t = document.elementFromPoint(b.x + b.width/2, b.y + b.height/2);
    return t ? (t.id || t.localName) : 'null'; };

  const items = [...document.querySelectorAll('.unified-extensions-item')];
  const btn = document.querySelector('#unified-extensions-button');
  out.push('pinned items: ' + items.length);
  for (const i of items) {
    out.push('  ' + (i.getAttribute('data-extensionid') || i.id)
             + ' ' + R(i) + ' onscreen=' + onScreen(i) + ' hit=' + hit(i));
  }
  out.push('ext button: ' + R(btn) + ' onscreen=' + onScreen(btn) + ' hit=' + hit(btn));

  // Leftmost icon x — the pixel sampler needs to know where to look.
  const xs = [...items, btn].map(e => e.getBoundingClientRect().x);
  out.push('SAMPLE_X=' + Math.round(Math.min(...xs)));

  const lastTab = [...document.querySelectorAll('.tabbrowser-tab')].pop();
  if (lastTab) {
    const lt = lastTab.getBoundingClientRect();
    out.push('last tab right=' + Math.round(lt.right)
             + ' first icon left=' + Math.round(Math.min(...xs))
             + ' OVERLAP=' + (lt.right > Math.min(...xs)));
  }
  cb(out.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""

JS_URLBAR = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  const win = {w: window.innerWidth, h: window.innerHeight};
  gURLBar.focus(); gURLBar.value = 'mozilla';
  gURLBar.startQuery({searchString: 'mozilla', allowAutofill: false});
  await new Promise(r => setTimeout(r, 2200));
  const nb = document.querySelector('#nav-bar').getBoundingClientRect();
  const inp = document.querySelector('#urlbar-input');
  const ib = inp.getBoundingClientRect();
  const t = document.elementFromPoint(ib.x + ib.width/2, ib.y + ib.height/2);
  cb(JSON.stringify({
    centred: Math.abs((nb.x + nb.width/2) - win.w/2) < 3,
    navbar: `${Math.round(nb.x)},${Math.round(nb.y)} ${Math.round(nb.width)}x${Math.round(nb.height)}`,
    inputHit: t ? (t.id || t.localName) : 'null',
  }));
} catch (e) { cb('ERR ' + e); }
})();
"""


def sample(png, x1, y1, x2, y2):
    r = subprocess.run(["swift", os.path.join(HERE, "px.swift"),
                        png, str(x1), str(y1), str(x2), str(y2)],
                       capture_output=True, text=True)
    return r.stdout.strip()


def main():
    proc = launch(build_profile(), 1280, 820)
    try:
        m = Marionette()
        m.new_session()
        for x in XPIS:
            m.send("Addon:Install", {"path": x, "temporary": False})
            time.sleep(2)
        time.sleep(6)
        m.content()
        m.navigate("https://example.com/")
        m.chrome()
        m.script("gBrowser.addTab('https://lobste.rs/', {triggeringPrincipal:"
                 " Services.scriptSecurityManager.getSystemPrincipal()});")
        time.sleep(3)

        res = m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS, "args": [], "newSandbox": False})["value"]
        print(res)
        png = "/tmp/ffmin/06-three-ext.png"
        m.screenshot(png)

        sx = 1100
        for line in res.splitlines():
            if line.startswith("SAMPLE_X="):
                sx = int(line.split("=")[1])
        # screenshots are 2x the CSS pixel grid
        print("\n--- pixels where the icons should be ---")
        print(sample(png, max(0, sx * 2 - 10), 0, 2530, 46))
        print("\n--- active tab, as a positive control ---")
        print(sample(png, 0, 0, 300, 44))

        print("\n--- urlbar still works? ---")
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS_URLBAR, "args": [], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/07-urlbar-with-ext.png")
        print("\n" + png)
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
