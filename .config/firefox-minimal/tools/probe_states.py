#!/usr/bin/env python3
"""
The extension icons must stay visible in EVERY state, including the one the
user hit: a new tab, where Firefox auto-focuses the address bar.

Checks four states and hit-tests each icon, because an element can report a
correct box and still be painted over or composited away.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

XPIS = ["/tmp/ublock-origin.xpi", "/tmp/sponsorblock.xpi"]

JS = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  const win = {w: window.innerWidth, h: window.innerHeight};
  const R = e => { const b = e.getBoundingClientRect();
    return `${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}`; };
  const visible = e => {
    const b = e.getBoundingClientRect();
    if (b.width < 1 || b.height < 1) return false;
    if (b.x < -1 || b.y < -1 || b.right > win.w + 2) return false;
    const c = getComputedStyle(e);
    if (c.visibility === 'hidden' || c.display === 'none') return false;
    if (parseFloat(c.opacity) < 0.05) return false;
    // an ancestor with opacity:0 composites the subtree away
    let n = e;
    while (n && n.nodeType === 1) {
      if (parseFloat(getComputedStyle(n).opacity) < 0.05) return false;
      n = n.parentElement;
    }
    // and it must actually be the thing under the cursor
    const hit = document.elementFromPoint(b.x + b.width / 2, b.y + b.height / 2);
    return !!(hit && (e === hit || e.contains(hit) || hit.contains(e)));
  };
  const ok = b => b ? 'PASS' : 'FAIL';
  let out = [];

  const report = (label) => {
    const items = [...document.querySelectorAll(
        '#nav-bar-customization-target .unified-extensions-item')];
    const btn = document.querySelector('#unified-extensions-button');
    const allVis = items.length > 0 && items.every(visible) && visible(btn);
    out.push(`[${label}]`);
    items.forEach(i => out.push(`   ${(i.getAttribute('data-extensionid')||i.id).slice(0,34).padEnd(36)}`
        + ` ${R(i)}  visible=${visible(i)}`));
    out.push(`   ${'(extensions button)'.padEnd(36)} ${R(btn)}  visible=${visible(btn)}`);
    out.push(`   ${ok(allVis)} all icons visible`);
    return allVis;
  };

  const results = [];

  // 1. idle on a page
  gURLBar.blur(); gBrowser.selectedBrowser.focus();
  await new Promise(r => setTimeout(r, 600));
  results.push(['idle on a page', report('idle on a page')]);

  // 2. address bar focused (Cmd+L)
  gURLBar.focus();
  await new Promise(r => setTimeout(r, 800));
  results.push(['urlbar focused', report('urlbar focused')]);
  out.push(`   prompt box: ${R(document.querySelector('#urlbar-container'))}`);

  // 3. typing, results panel open
  gURLBar.value = 'moz';
  gURLBar.startQuery({searchString: 'moz', allowAutofill: false});
  await new Promise(r => setTimeout(r, 2200));
  results.push(['results open', report('results open')]);
  const v = document.querySelector('.urlbarView');
  out.push(`   results panel: ${v ? R(v) : 'none'}`);

  // 4. NEW TAB — the reported case; Firefox auto-focuses the urlbar here
  gURLBar.blur();
  await new Promise(r => setTimeout(r, 400));
  gBrowser.selectedTab = gBrowser.addTab('about:newtab', {
    triggeringPrincipal: Services.scriptSecurityManager.getSystemPrincipal()});
  await new Promise(r => setTimeout(r, 2500));
  out.push(`   urlbar focused on new tab? ${document.querySelector('#urlbar').hasAttribute('focused')}`);
  results.push(['NEW TAB', report('NEW TAB')]);

  out.push('');
  out.push('SUMMARY: ' + results.map(([n, p]) => `${n}=${p ? 'PASS' : 'FAIL'}`).join('  '));
  out.push(results.every(([, p]) => p) ? 'ALL STATES PASS' : 'SOME STATES FAIL');
  cb(out.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""


def main():
    proc = launch(build_profile(), 1300, 850)
    try:
        m = Marionette()
        m.new_session()
        for x in XPIS:
            if os.path.exists(x):
                m.send("Addon:Install", {"path": x, "temporary": False})
                time.sleep(2)
        time.sleep(4)
        m.content()
        m.navigate("https://example.com/")
        m.chrome()
        time.sleep(2)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS, "args": [], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/newtab-icons.png")
        print("\n/tmp/ffmin/newtab-icons.png")
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
