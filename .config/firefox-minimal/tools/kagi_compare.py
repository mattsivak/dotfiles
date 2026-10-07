#!/usr/bin/env python3
"""
Measure the regressions visible in the user's screenshot:
  1. content column squeezed left, huge dead space right
  2. a tall empty box beside the share / kebab icons
  3. "Blast from the Past" still framed, with slack at the bottom
  4. the search input's prompt/cursor artefact

Compares STOCK Kagi (no CSS) against OURS, so a number is only a defect if it
differs from what Kagi itself does.
"""
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


MEASURE = r"""
const cb = arguments[arguments.length - 1];
(async () => {
try {
  const nm = n => n.localName + (n.id ? '#' + n.id : '')
    + (n.className && typeof n.className === 'string' && n.className.trim()
       ? '.' + n.className.trim().split(/\s+/).join('.') : '');
  const R = e => { const b = e.getBoundingClientRect();
    return `${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}`; };
  const W = e => Math.round(e.getBoundingClientRect().width);
  let out = [];
  out.push('viewport: ' + window.innerWidth + 'x' + window.innerHeight);

  out.push('');
  out.push('-- CONTENT WIDTH CHAIN --');
  for (const sel of ['html','body','#_0_app_content','main#main','.center-content-box',
                     '#layout-v2','#page0','.search-result']) {
    const e = document.querySelector(sel);
    if (e) {
      const c = getComputedStyle(e);
      out.push(`  ${sel.padEnd(22)} ${R(e)} maxw=${c.maxWidth} w=${c.width} mar=${c.margin.replace(/\s+/g,',')}`);
    }
  }
  const rootVars = getComputedStyle(document.documentElement);
  for (const v of ['--center_content_width','--center_content_min_width',
                   '--app_content_padding','--center_content_padding']) {
    const val = rootVars.getPropertyValue(v).trim();
    if (val) out.push(`  var ${v} = ${val}`);
  }

  out.push('');
  out.push('-- SHARE / KEBAB AREA (the tall empty box) --');
  document.querySelectorAll('.more_search_dropdown_box, .share-button, .serp_nav_end,'
    + ' .sidebar-filter-nav, [class*=share], .k_ui_dropdown').forEach(e => {
    const r = e.getBoundingClientRect();
    if (!r.width || r.y > 450) return;
    const c = getComputedStyle(e);
    out.push(`  ${nm(e)} ${R(e)} bd=${c.borderTopWidth} disp=${c.display}`
             + ` pad=${c.padding.replace(/\s+/g,',')} minh=${c.minHeight}`);
  });

  out.push('');
  out.push('-- FILTER PILLS --');
  document.querySelectorAll('.filter-item').forEach((e,i) => {
    if (i > 5) return;
    const c = getComputedStyle(e);
    out.push(`  ${nm(e)} ${R(e)} disp=${c.display} pad=${c.padding.replace(/\s+/g,',')}`
             + ` minh=${c.minHeight} align=${c.alignItems}`);
  });

  out.push('');
  out.push('-- BLAST FROM THE PAST / WIDGETS --');
  document.querySelectorAll('.list-widget, .widgetContent, .widget-simple,'
    + ' .widgetItem, .widgetHeader, [class*=widgetTitle]').forEach(e => {
    const r = e.getBoundingClientRect();
    if (!r.width) return;
    const c = getComputedStyle(e);
    out.push(`  ${nm(e)} ${R(e)} bd=${c.borderTopWidth} pad=${c.padding.replace(/\s+/g,',')}`
             + ` mar=${c.margin.replace(/\s+/g,',')} bg=${c.backgroundColor}`);
  });

  out.push('');
  out.push('-- SEARCH INPUT --');
  for (const sel of ['.search-input-container','#searchInput','input[type=text]',
                     '.search-form','#clear_searchBar','#searchFormSubmit']) {
    const e = document.querySelector(sel);
    if (!e) continue;
    const c = getComputedStyle(e);
    out.push(`  ${sel.padEnd(26)} ${R(e)} pad=${c.padding.replace(/\s+/g,',')}`
             + ` bd=${c.borderTopWidth} bg=${c.backgroundColor}`);
  }
  const sic = document.querySelector('.search-input-container');
  if (sic) {
    const b = getComputedStyle(sic, '::before');
    out.push(`  ::before content=${b.content} w=${b.width} pad=${b.padding.replace(/\s+/g,',')}`);
  }
  cb(out.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""

INJECT = r"""
const cb = arguments[arguments.length - 1];
const css = arguments[0];
document.querySelectorAll('style[data-mz]').forEach(s => s.remove());
const s = document.createElement('style');
s.setAttribute('data-mz','1'); s.textContent = css;
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
            print("signed out"); return

        print("#" * 30, "STOCK KAGI (no custom css)", "#" * 30)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": MEASURE, "args": [], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/kagi-stock.png")

        m.send("WebDriver:ExecuteAsyncScript",
               {"script": INJECT, "args": [open(CSS).read()], "newSandbox": False})
        print()
        print("#" * 30, "WITH OUR CSS", "#" * 30)
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": MEASURE, "args": [], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/kagi-ours.png")
        print("\n/tmp/ffmin/kagi-stock.png  /tmp/ffmin/kagi-ours.png")
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
