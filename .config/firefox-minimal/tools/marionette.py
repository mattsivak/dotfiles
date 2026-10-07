#!/usr/bin/env python3
"""
Marionette client just big enough to screenshot Firefox's chrome.

Firefox's own remote-protocol server; no geckodriver, no selenium. Launch with
    /Applications/Firefox.app/Contents/MacOS/firefox \
        --profile <dir> --marionette --no-remote --new-instance
then speak this protocol on 127.0.0.1:2828.

Why chrome context: WebDriver:TakeScreenshot in "chrome" context captures the
whole browser window including toolbars, which is the thing being styled.
screencapture(1) needs Screen Recording and fails here, so this is the only
way to see our own work.
"""

import base64
import json
import pathlib
import socket
import subprocess
import sys
import time

FIREFOX = "/Applications/Firefox.app/Contents/MacOS/firefox"
HOST, PORT = "127.0.0.1", 2828


class Marionette:
    def __init__(self, host=HOST, port=PORT, timeout=60):
        deadline = time.time() + timeout
        last = None
        while time.time() < deadline:
            try:
                self.sock = socket.create_connection((host, port), timeout=30)
                break
            except OSError as e:
                last = e
                time.sleep(0.5)
        else:
            raise RuntimeError(f"marionette never came up: {last}")

        self.sock.settimeout(60)
        self.buf = b""
        self._recv()  # server-side handshake packet
        self.msgid = 0

    # --- wire format: "<len>:<json>" ------------------------------------
    def _recv(self):
        while b":" not in self.buf:
            self.buf += self.sock.recv(65536)
        length, _, rest = self.buf.partition(b":")
        n = int(length)
        self.buf = rest
        while len(self.buf) < n:
            self.buf += self.sock.recv(65536)
        payload, self.buf = self.buf[:n], self.buf[n:]
        return json.loads(payload)

    def send(self, name, params=None):
        self.msgid += 1
        body = json.dumps([0, self.msgid, name, params or {}]).encode()
        self.sock.sendall(str(len(body)).encode() + b":" + body)
        while True:
            msg = self._recv()
            if msg[0] == 1 and msg[1] == self.msgid:
                if msg[2] is not None:
                    raise RuntimeError(f"{name}: {msg[2]}")
                return msg[3]

    # --- api -------------------------------------------------------------
    def new_session(self):
        return self.send("WebDriver:NewSession", {"capabilities": {}})

    def chrome(self):
        self.send("Marionette:SetContext", {"value": "chrome"})

    def content(self):
        self.send("Marionette:SetContext", {"value": "content"})

    def navigate(self, url):
        self.send("WebDriver:Navigate", {"url": url})

    def screenshot(self, path, full=True):
        r = self.send("WebDriver:TakeScreenshot", {"full": full, "hash": False})
        data = base64.b64decode(r["value"])
        pathlib.Path(path).write_bytes(data)
        return path

    def script(self, js, args=None):
        return self.send(
            "WebDriver:ExecuteScript",
            {"script": js, "args": args or [], "newSandbox": False},
        )["value"]

    def quit(self):
        try:
            self.send("Marionette:Quit", {"flags": ["eForceQuit"]})
        except Exception:
            pass
        self.sock.close()


def launch(profile, width=1280, height=800):
    proc = subprocess.Popen(
        [
            FIREFOX,
            "--profile", str(profile),
            "--marionette",
            # Firefox 136+ gates Marionette's "chrome" context behind this
            # flag. Without it SetContext fails with "System access is
            # required", and chrome screenshots are impossible.
            "-remote-allow-system-access",
            "--no-remote",
            "--new-instance",
            "--window-size", f"{width},{height}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return proc


# --- profile construction, shared by the probes and the shooter -------------
# A probe that reuses whatever profile the last run happened to leave behind
# will silently test stale CSS. Rebuilding is cheap; always do it.

_MARIONETTE_PREFS = """
// test-harness only, not part of the delivered config
user_pref("marionette.port", 2828);
user_pref("marionette.enabled", true);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("trailhead.firstrun.didSeeAboutWelcome", true);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("app.normandy.first_run", false);
"""


def build_profile(src=None, profile="/tmp/ffmin/profile"):
    """Create a throwaway profile carrying the current CSS. Returns its path."""
    import pathlib as _p
    import shutil as _sh
    src = _p.Path(src or _p.Path(__file__).resolve().parent.parent)
    prof = _p.Path(profile)
    if prof.exists():
        _sh.rmtree(prof)
    chrome = prof / "chrome"
    chrome.mkdir(parents=True)
    _sh.copy(src / "userChrome.css", chrome / "userChrome.css")
    _sh.copy(src / "userContent.css", chrome / "userContent.css")
    (prof / "user.js").write_text((src / "user.js").read_text() + _MARIONETTE_PREFS)
    return prof


if __name__ == "__main__":
    print("library module; import from a test script", file=sys.stderr)
