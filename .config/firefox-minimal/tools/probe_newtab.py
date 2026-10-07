#!/usr/bin/env python3
"""
Can Cmd+T open a new tab with the search prompt already focused?

Two separate questions:
  1. On about:blank (our configured new tab), does Firefox focus the urlbar?
  2. Which pref controls it, and does the prompt actually accept typing?

browser.startup.page=0 + browser.newtabpage.enabled=false gives us
about:blank, which historically does NOT auto-focus the urlbar the way
about:newtab does. That is the likely cause.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette, build_profile, launch  # noqa: E402

CMD, TAB = "\ue03d", "\ue004"


def press(m, seq):
    acts = []
    for v in seq:
        acts.append({"type": "keyDown", "value": v})
    for v in reversed(seq):
        acts.append({"type": "keyUp", "value": v})
    m.send("WebDriver:PerformActions",
           {"actions": [{"type": "key", "id": "kb", "actions": acts}]})
    time.sleep(0.8)


STATE = """
const u = document.querySelector('#urlbar');
const a = document.activeElement;
return JSON.stringify({
  tabs: gBrowser.tabs.length,
  url: gBrowser.selectedBrowser.currentURI.spec,
  urlbarFocused: u.hasAttribute('focused'),
  active: a ? (a.id || a.localName) : 'none',
  urlbarValue: gURLBar.value,
  newtabPref: Services.prefs.getBoolPref('browser.newtabpage.enabled', true),
  newtabURL: Services.prefs.getStringPref('browser.newtab.url', '(unset)'),
});
"""


def main():
    proc = launch(build_profile(), 1300, 850)
    try:
        m = Marionette()
        m.new_session()
        m.content()
        m.navigate("https://example.com/")
        m.chrome()
        time.sleep(2)

        print("--- before ---")
        print(m.script(STATE))

        print("\n--- after a real Cmd+T ---")
        press(m, [CMD, "t"])
        time.sleep(1.5)
        print(m.script(STATE))

        # Can we type straight away?
        m.send("WebDriver:PerformActions", {"actions": [{
            "type": "key", "id": "kb",
            "actions": [{"type": "keyDown", "value": c} for c in "kagi"] +
                       [{"type": "keyUp", "value": c} for c in "kagi"]}]})
        time.sleep(1.2)
        print("\n--- after typing 'kagi' ---")
        print(m.script(STATE))

        m.quit()
    finally:
        time.sleep(1)
        if proc.poll() is None:
            proc.terminate()


if __name__ == "__main__":
    main()
