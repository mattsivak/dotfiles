#!/usr/bin/env python3
"""
Diagnose kagi.css ON the real SERP: inject it, then measure exactly which
elements get doubled rules, stray borders, or lost padding.
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


JS = r"""
const cb = arguments[arguments.length - 1];
const css = arguments[0];
(async () => {
try {
  document.querySelectorAll('style[data-mz]').forEach(s => s.remove());
  const st = document.createElement('style');
  st.setAttribute('data-mz','1'); st.textContent = css;
  document.head.appendChild(st);
  await new Promise(r => setTimeout(r, 1200));

  const nm = n => n.localName + (n.id ? '#' + n.id : '')
    + (n.className && typeof n.className === 'string' && n.className.trim()
       ? '.' + n.className.trim().split(/\s+/).join('.') : '');
  const R = e => { const b = e.getBoundingClientRect();
    return `${Math.round(b.x)},${Math.round(b.y)} ${Math.round(b.width)}x${Math.round(b.height)}`; };
  const hasRule = e => getComputedStyle(e, '::before').borderLeftWidth !== '0px'
                    && getComputedStyle(e, '::before').content !== 'none';
  let out = [];

  // --- A. who draws a guide rule, and do any nest? ----------------------
  out.push('=== ELEMENTS DRAWING A ::before GUIDE ===');
  const drawers = [...document.querySelectorAll(
      '.search-result, ._0_SRI, .__srgi, .sri-group')].filter(hasRule);
  out.push('count: ' + drawers.length);
  let nested = 0;
  drawers.forEach(d => {
    const inner = drawers.filter(o => o !== d && d.contains(o));
    if (inner.length) {
      nested++;
      out.push(`  NESTED: ${nm(d)} ${R(d)}`);
      inner.forEach(o => out.push(`     contains ${nm(o)} ${R(o)}`));
    }
  });
  out.push('nested pairs (=> doubled rule): ' + nested);

  // --- B. widget items wrongly treated as results ------------------------
  out.push('');
  out.push('=== WIDGET ITEMS CARRYING _0_SRI ===');
  const wi = [...document.querySelectorAll('.widgetItem')];
  out.push('widgetItems: ' + wi.length
           + ' | also ._0_SRI: ' + wi.filter(w => w.classList.contains('_0_SRI')).length
           + ' | drawing a guide: ' + wi.filter(hasRule).length);
  wi.slice(0, 3).forEach(w => {
    const c = getComputedStyle(w);
    out.push(`  ${nm(w)} ${R(w)} pad=${c.padding.replace(/\s+/g,',')} `
             + `mar=${c.margin.replace(/\s+/g,',')} guide=${hasRule(w)}`);
  });

  // --- C. stray borders on small icon buttons ---------------------------
  out.push('');
  out.push('=== SMALL ICON BUTTONS WITH A BORDER ===');
  let bordered = 0, sample = [];
  document.querySelectorAll('button, .btn, [role=button]').forEach(b => {
    const r = b.getBoundingClientRect();
    if (!r.width || r.width > 60) return;
    const c = getComputedStyle(b);
    const txt = (b.textContent || '').trim();
    if (parseFloat(c.borderTopWidth) > 0 && !txt) {
      bordered++;
      if (sample.length < 5)
        sample.push(`  ${nm(b)} ${R(b)} bd=${c.borderTopWidth} pad=${c.padding}`);
    }
  });
  out.push('icon-only buttons with a border: ' + bordered);
  out.push(sample.join('\n'));

  // --- C2. ANY bordered element inside a result row ---------------------
  out.push('');
  out.push('=== ANY BORDERED ELEMENT INSIDE A RESULT ===');
  const res = document.querySelector('._0_SRI.search-result');
  if (res) {
    let found = [];
    res.querySelectorAll('*').forEach(e => {
      const c = getComputedStyle(e);
      const bw = parseFloat(c.borderTopWidth) + parseFloat(c.borderLeftWidth)
               + parseFloat(c.borderRightWidth) + parseFloat(c.borderBottomWidth);
      if (bw > 0) found.push(`  ${nm(e)} ${R(e)} bd=${c.borderWidth.replace(/\s+/g,',')}`
                             + ` color=${c.borderTopColor.replace(/\s/g,'')}`);
    });
    out.push(found.length ? found.join('\n') : '  (none)');
  }

  // --- C3. top filter bar controls --------------------------------------
  out.push('');
  out.push('=== TOP FILTER BAR ===');
  document.querySelectorAll('.sidebar-filter-nav-form, .sidebar-filter-nav,'
    + ' .k_ui_dropdown, .dd-toggle, .filter-item').forEach((e,i) => {
    if (i > 9) return;
    const r = e.getBoundingClientRect();
    if (r.width === 0 || r.y > 400) return;
    const c = getComputedStyle(e);
    out.push(`  ${nm(e)} ${R(e)} bd=${c.borderTopWidth} pad=${c.padding.replace(/\s+/g,',')}`
             + ` h=${Math.round(r.height)}`);
  });

  // --- D. nested boxed panels (border inside border) --------------------
  out.push('');
  out.push('=== NESTED BORDERED PANELS ===');
  const boxed = [...document.querySelectorAll(
      '.widgetContent,.widgetItem,.widgetItems,.inline-content,.list-widget,'
      + '.related-items,.instant-answer,.ia-wrapper,.results_meta,.wikipediaResult')]
      .filter(e => parseFloat(getComputedStyle(e).borderTopWidth) > 0);
  out.push('bordered panels: ' + boxed.length);
  boxed.forEach(b => {
    const inner = boxed.filter(o => o !== b && b.contains(o));
    if (inner.length) {
      out.push(`  OUTER ${nm(b)} ${R(b)}`);
      inner.slice(0,3).forEach(o => out.push(`     INNER ${nm(o)} ${R(o)}`));
    }
  });

  // --- E. the results-count line ----------------------------------------
  out.push('');
  out.push('=== RESULTS COUNT LINE ===');
  const metas = [...document.querySelectorAll('div,span,p')].filter(e =>
      /relevant results in/.test(e.textContent || '') && e.children.length <= 1);
  const meta = metas[metas.length - 1];
  if (meta) {
    const c = getComputedStyle(meta);
    out.push(`  ${nm(meta)} ${R(meta)}`);
    out.push(`    border=${c.borderTopWidth}/${c.borderTopColor.replace(/\s/g,'')} `
             + `bg=${c.backgroundColor} pad=${c.padding.replace(/\s+/g,',')}`);
    let p = meta.parentElement, d = 0;
    while (p && d < 2) { out.push('    < ' + nm(p)); p = p.parentElement; d++; }
  } else out.push('  (not found)');

  // --- F. font coverage --------------------------------------------------
  out.push('');
  out.push('=== FONTS AFTER INJECTION (want Hack everywhere) ===');
  for (const sel of ['body','.__sri_title_link','.__sri-desc','.widgetItemTitle',
                     '.widgetContent','h1','h2','h3','.serp-nav','.summarize-link']) {
    const e = document.querySelector(sel);
    if (e) out.push(`  ${sel.padEnd(22)} ${getComputedStyle(e).fontFamily.split(',')[0]}`);
  }

  // --- G. padding of result internals -----------------------------------
  out.push('');
  out.push('=== RESULT SPACING ===');
  const r0 = document.querySelector('._0_SRI.search-result');
  if (r0) {
    for (const sel of [':scope', '.__sri-title', '.__sri-url-box', '.__sri-body', '.__sri-desc']) {
      const e = sel === ':scope' ? r0 : r0.querySelector(sel);
      if (e) { const c = getComputedStyle(e);
        out.push(`  ${sel.padEnd(16)} pad=${c.padding.replace(/\s+/g,',')} `
                 + `mar=${c.margin.replace(/\s+/g,',')} ${R(e)}`); }
    }
  }
  cb(out.join('\n'));
} catch (e) { cb('ERR ' + e + '\n' + e.stack); }
})();
"""


def main():
    prof = make_copy()
    proc = launch(prof, 1500, 1200)
    try:
        m = Marionette(port=2830)
        m.new_session()
        m.content()
        m.navigate("https://kagi.com/search?q=test&no_css")
        time.sleep(6)
        if m.script("return /signin/i.test(location.pathname);"):
            print("signed out — cannot inspect")
            return
        css = open(CSS).read()
        print(m.send("WebDriver:ExecuteAsyncScript",
                     {"script": JS, "args": [css], "newSandbox": False})["value"])
        m.screenshot("/tmp/ffmin/kagi-live-current.png")
        print("\n/tmp/ffmin/kagi-live-current.png")
        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
