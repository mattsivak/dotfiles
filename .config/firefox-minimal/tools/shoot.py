#!/usr/bin/env python3
"""
Build a throwaway Firefox profile with the minimal chrome applied and
screenshot it. Never touches the real profile.

    python3 tools/shoot.py

Writes PNGs into /tmp/ffmin/.
"""

import os
import pathlib
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

HERE = pathlib.Path(__file__).resolve().parent.parent
PROFILE = pathlib.Path("/tmp/ffmin/profile")
OUT = pathlib.Path("/tmp/ffmin")



def main():
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"profile: {build_profile()}")
    proc = launch(PROFILE, 1280, 820)
    print(f"firefox pid {proc.pid}")
    try:
        m = Marionette()
        m.new_session()

        # Open a few tabs so the strip has something to show.
        m.content()
        m.navigate("https://news.ycombinator.com/")
        for url in ("https://lobste.rs/", "https://developer.mozilla.org/"):
            m.chrome()
            m.script("gBrowser.addTab(arguments[0], {triggeringPrincipal:"
                     " Services.scriptSecurityManager.getSystemPrincipal()});",
                     [url])
        time.sleep(4)

        m.chrome()
        # Make sure the first tab is selected and the window is sized right.
        m.script("gBrowser.selectedTab = gBrowser.tabs[0];"
                 " window.resizeTo(1280, 820); window.moveTo(0, 0);")
        time.sleep(1.5)
        print(m.screenshot(OUT / "01-idle.png"))

        # Summon the urlbar and type something -> dmenu state.
        m.script("gURLBar.focus(); gURLBar.select();")
        time.sleep(0.4)
        m.script("gURLBar.value = 'mozilla'; "
                 "gURLBar.handleCommand === undefined;")
        m.script("gURLBar.startQuery({searchString: 'mozilla', "
                 "allowAutofill: false});")
        time.sleep(2.5)
        print(m.screenshot(OUT / "02-urlbar.png"))

        # Findbar.
        m.script("gURLBar.blur(); gBrowser.selectedBrowser.focus();")
        time.sleep(0.3)
        m.script("gLazyFindCommand ? gLazyFindCommand('onFindCommand') :"
                 " gFindBar.onFindCommand();")
        time.sleep(0.8)
        m.script("gFindBar._findField.value = 'the';"
                 " gFindBar._find('the');")
        time.sleep(1.2)
        print(m.screenshot(OUT / "03-findbar.png"))

        # Report the live geometry we care about, rather than trusting the CSS.
        geom = m.script("""
          const q = s => { const e = document.querySelector(s);
            if (!e) return null;
            const r = e.getBoundingClientRect();
            return {x: Math.round(r.x), y: Math.round(r.y),
                    w: Math.round(r.width), h: Math.round(r.height),
                    display: getComputedStyle(e).display,
                    opacity: getComputedStyle(e).opacity}; };
          return JSON.stringify({
            toolbox: q('#navigator-toolbox'),
            tabs:    q('#TabsToolbar'),
            navbar:  q('#nav-bar'),
            personal:q('#PersonalToolbar'),
            titlebar_buttons: q('.titlebar-buttonbox-container'),
            tab0:    q('.tabbrowser-tab[selected]'),
            content: q('#tabbrowser-tabpanels'),
            tabcount: gBrowser.tabs.length,
          }, null, 1);
        """)
        print("GEOMETRY:", geom)
        (OUT / "geometry.json").write_text(geom)

        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()
            time.sleep(1)
        if proc.poll() is None:
            proc.kill()


if __name__ == "__main__":
    main()
