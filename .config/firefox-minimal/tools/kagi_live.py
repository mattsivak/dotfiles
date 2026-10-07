#!/usr/bin/env python3
"""
Iterate kagi.css against the REAL Kagi SERP.

Kagi's /search needs a session, so the mock in preview/ could only ever prove
the CSS was valid, not that its selectors match today's markup. This drives a
COPY of the logged-in scratch profile (the user's own window is left running
and untouched), loads a real results page with ?no_css to get Kagi's stock
markup, then injects kagi.css as a <style> tag — the same way Kagi's settings
inject it — so fixes can be tested without touching the account.

    python3 tools/kagi_live.py --dump          structure of the problem areas
    python3 tools/kagi_live.py --shot a.png    inject CSS, screenshot
    python3 tools/kagi_live.py --raw b.png     stock page, no CSS

Reads page structure only. Never prints cookies, tokens or account data.
"""
import argparse
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
QUERY = "test"

MARIONETTE_PREFS = """
user_pref("marionette.port", 2830);
user_pref("marionette.enabled", true);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
"""


def make_copy():
    """Copy the session profile so the user's own window keeps running."""
    os.makedirs(WORK, exist_ok=True)
    subprocess.run([
        "rsync", "-a", "--delete",
        "--exclude", "cache2", "--exclude", "startupCache",
        "--exclude", "shader-cache", "--exclude", "*.sqlite-wal",
        LIVE + "/", WORK + "/",
    ], check=True)
    with open(os.path.join(WORK, "user.js"), "a") as f:
        f.write(MARIONETTE_PREFS)
    return WORK


JS_DUMP = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  const nm = n => n.localName
    + (n.id ? '#' + n.id : '')
    + (n.className && typeof n.className === 'string' && n.className.trim()
       ? '.' + n.className.trim().split(/\s+/).join('.') : '');
  const R = e => { const b = e.getBoundingClientRect();
    return `${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}`; };
  let out = [];

  // --- 1. result items: ancestor chain, to find the doubled guide rule ----
  out.push('=== RESULT ITEMS: own classes < ancestors ===');
  const items = [...document.querySelectorAll(
      '.search-result, ._0_SRI, .__srgi, .sri-group, .sr-group')].slice(0, 8);
  items.forEach((r, i) => {
    const chain = [];
    let n = r.parentElement, d = 0;
    while (n && d < 4) { chain.push(nm(n)); n = n.parentElement; d++; }
    out.push(`[${i}] ${nm(r)} ${R(r)}`);
    out.push(`      < ${chain.join(' < ')}`);
  });

  // --- 2. full subtree of result #1, to identify the icon buttons --------
  const first = document.querySelector('.search-result, ._0_SRI');
  if (first) {
    out.push('');
    out.push('=== FIRST RESULT SUBTREE ===');
    const walk = (n, d) => {
      if (d > 4) return;
      const c = getComputedStyle(n);
      if (c.display === 'none') return;
      out.push('  '.repeat(d) + nm(n) + ' ' + R(n)
               + ` bd=${c.borderTopWidth}/${c.borderTopColor.replace(/\s/g,'')}`
               + ` pad=${c.padding.replace(/\s+/g,',')}`);
      for (const k of n.children) walk(k, d + 1);
    };
    walk(first, 0);
  }

  // --- 3. the results-count line -----------------------------------------
  out.push('');
  out.push('=== RESULTS META / COUNT LINE ===');
  for (const el of document.querySelectorAll('*')) {
    const t = (el.textContent || '').trim();
    if (/relevant results in/.test(t) && el.children.length <= 2) {
      const c = getComputedStyle(el);
      out.push('  ' + nm(el) + ' ' + R(el)
               + ` bd=${c.border.replace(/\s+/g,' ')} pad=${c.padding} bg=${c.backgroundColor}`);
      let n = el.parentElement, d = 0;
      while (n && d < 3) { out.push('    < ' + nm(n)); n = n.parentElement; d++; }
      break;
    }
  }

  // --- 4. "Blast from the Past" style widget ------------------------------
  out.push('');
  out.push('=== WIDGET BLOCKS ===');
  const widgets = document.querySelectorAll(
      '.widgetContent, .widgetItem, .widgetItems, .inline-content, [class*=widget]');
  const seen = new Set();
  [...widgets].slice(0, 12).forEach(w => {
    if (seen.has(w)) return; seen.add(w);
    const c = getComputedStyle(w);
    out.push('  ' + nm(w) + ' ' + R(w)
             + ` font=${c.fontFamily.split(',')[0]} bd=${c.borderTopWidth}`
             + ` pad=${c.padding.replace(/\s+/g,',')} bg=${c.backgroundColor}`);
  });

  // --- 5. every small icon-only button near results -----------------------
  out.push('');
  out.push('=== ICON BUTTONS (small, bordered) ===');
  const cands = document.querySelectorAll('button, .btn, [role=button], a.btn');
  const rows = [];
  cands.forEach(b => {
    const r = b.getBoundingClientRect();
    if (r.width === 0 || r.width > 60 || r.height > 60) return;
    const c = getComputedStyle(b);
    const txt = (b.textContent || '').trim().slice(0, 18);
    rows.push('  ' + nm(b) + ' ' + R(b)
              + ` bd=${c.borderTopWidth}/${c.borderTopColor.replace(/\s/g,'')}`
              + ` txt="${txt}" svg=${b.querySelector('svg,img,i') ? 'y' : 'n'}`);
  });
  out.push(rows.slice(0, 18).join('\n') || '  (none)');

  // --- 6. what fonts are actually winning ---------------------------------
  out.push('');
  out.push('=== FONT SPOT-CHECK ===');
  for (const sel of ['body', '.__sri_title_link', '.__sri-desc', 'h1', 'h2',
                     '.widgetContent', '.serp-nav']) {
    const e = document.querySelector(sel);
    if (e) out.push(`  ${sel.padEnd(20)} ${getComputedStyle(e).fontFamily.split(',')[0]}`);
  }

  cb(out.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""

INJECT = r"""
const cb = arguments[arguments.length - 1];
const css = arguments[0];
(async () => {
  document.querySelectorAll('style[data-mz]').forEach(s => s.remove());
  const s = document.createElement('style');
  s.setAttribute('data-mz', '1');
  s.textContent = css;
  document.head.appendChild(s);
  await new Promise(r => setTimeout(r, 900));
  cb('injected ' + css.length + ' chars');
})();
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", action="store_true")
    ap.add_argument("--shot")
    ap.add_argument("--raw")
    ap.add_argument("--query", default=QUERY)
    a = ap.parse_args()

    prof = make_copy()
    proc = launch(prof, 1500, 1200)
    try:
        m = Marionette(port=2830)
        m.new_session()
        m.content()
        url = f"https://kagi.com/search?q={a.query}&no_css"
        m.navigate(url)
        time.sleep(6)

        title = m.script("return document.title;")
        signed_out = m.script(
            "return /signin|sign in/i.test(location.pathname + document.title);")
        print(f"page: {title!r}  signed_out={signed_out}")
        if signed_out:
            print("No Kagi session in this profile — cannot inspect a real SERP.")
            return

        if a.raw:
            m.screenshot(a.raw)
            print(a.raw)

        if a.dump:
            print(m.send("WebDriver:ExecuteAsyncScript",
                         {"script": JS_DUMP, "args": [], "newSandbox": False})["value"])

        if a.shot:
            css = open(CSS).read()
            print(m.send("WebDriver:ExecuteAsyncScript",
                         {"script": INJECT, "args": [css], "newSandbox": False})["value"])
            time.sleep(1)
            m.screenshot(a.shot)
            print(a.shot)
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
