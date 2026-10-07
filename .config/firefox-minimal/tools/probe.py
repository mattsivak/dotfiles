#!/usr/bin/env python3
"""Probe #3: dump the real urlbar subtree so selectors stop being guesses."""
import os
import pathlib
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

PROFILE = pathlib.Path("/tmp/ffmin/profile")

JS = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  gURLBar.focus();
  gURLBar.value = 'mozilla';
  gURLBar.startQuery({searchString: 'mozilla', allowAutofill: false});
  await new Promise(r => setTimeout(r, 2500));

  const name = n => n.localName
      + (n.id ? '#' + n.id : '')
      + (n.className && typeof n.className === 'string'
         ? '.' + n.className.trim().split(/\s+/).join('.') : '');

  const dump = (n, d, max) => {
    if (d > max) return [];
    const c = getComputedStyle(n);
    const b = n.getBoundingClientRect();
    if (c.display === 'none') return [];
    const line = '  '.repeat(d) + name(n)
      + ` [${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}]`
      + ` bg=${c.backgroundColor} pos=${c.position}`
      + (c.left !== 'auto' ? ` left=${c.left}` : '')
      + (c.transform !== 'none' ? ` tf=${c.transform}` : '');
    let out = [line];
    for (const k of n.children) out = out.concat(dump(k, d + 1, max));
    return out;
  };

  let res = [];
  res.push('--- #nav-bar subtree ---');
  res = res.concat(dump(document.querySelector('#nav-bar'), 0, 6));
  res.push('--- window: ' + window.innerWidth + 'x' + window.innerHeight);
  res.push('--- urlbar attrs: ' + [...document.querySelector('#urlbar').attributes].map(a=>a.name+'='+a.value).join(' '));
  cb(res.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""


def main():
    proc = launch(build_profile(), 1280, 820)
    try:
        m = Marionette()
        m.new_session()
        m.content()
        m.navigate("https://example.com/")
        m.chrome()
        time.sleep(2)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS, "args": [], "newSandbox": False})["value"])
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
