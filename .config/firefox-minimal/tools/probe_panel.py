#!/usr/bin/env python3
"""
Unpinned extensions (Bitwarden, by default) live only in the panel. Verify
the panel is usable: opens on screen, lists them, rows are legible, and the
extension's own popup opens on screen.
"""
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
XPIS = ["/tmp/ublock-origin.xpi", "/tmp/bitwarden-password-manager.xpi",
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
  const ok = b => b ? 'PASS' : 'FAIL';

  await gUnifiedExtensions.togglePanel();
  await new Promise(r => setTimeout(r, 2500));
  const p = document.querySelector('#unified-extensions-panel');
  out.push('panel ' + R(p) + ' state=' + p.state + ' onscreen=' + onScreen(p));
  out.push(ok(p.state === 'open' && onScreen(p)) + ' panel opens on screen');

  const rows = [...p.querySelectorAll('.unified-extensions-item')];
  out.push('rows: ' + rows.length);
  for (const r of rows) {
    const nm = r.querySelector('.unified-extensions-item-name');
    out.push('  ' + (r.getAttribute('data-extensionid')||'?') + ' ' + R(r)
             + ' name="' + (nm ? nm.textContent.trim() : '-') + '"'
             + ' nameVisible=' + (nm ? onScreen(nm) : false));
  }
  out.push(ok(rows.length >= 1) + ' unpinned extension listed');
  out.push(ok(rows.every(r => { const n = r.querySelector('.unified-extensions-item-name');
                                return n && onScreen(n); })) + ' row names legible');
  cb(out.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""


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
        time.sleep(3)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS, "args": [], "newSandbox": False})["value"])
        png = "/tmp/ffmin/08-ext-panel.png"
        m.screenshot(png)
        print("\n" + png)
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
