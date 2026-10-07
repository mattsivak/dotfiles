#!/usr/bin/env python3
"""
Install extensions into a profile through Firefox's own addon manager.

NOT by copying XPIs into <profile>/extensions/ — Firefox registers extensions
in extensions.json with per-profile state, so a dropped-in file is at best
ignored and at worst leaves an inconsistent profile. Marionette's
Addon:Install runs the real install path, the same one the AMO button uses.

    python3 tools/install_addons.py --profile <dir> [--dry-run] <xpi>...

Refuses to touch a profile that Firefox currently has open.
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
import time
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from marionette import Marionette  # noqa: E402

FIREFOX = "/Applications/Firefox.app/Contents/MacOS/firefox"
PORT = 2831


def describe(xpi):
    """Read an XPI's real identity from its own manifest, resolving __MSG_."""
    with zipfile.ZipFile(xpi) as z:
        man = json.loads(z.read("manifest.json"))
        name = man.get("name", "?")
        if name.startswith("__MSG_"):
            key = name[6:-2] if name.endswith("__") else name[6:]
            for loc in ("en", "en_US"):
                try:
                    msgs = json.loads(z.read(f"_locales/{loc}/messages.json"))
                    if key in msgs:
                        name = msgs[key].get("message", name)
                        break
                except KeyError:
                    continue
        signed = any(n.startswith("META-INF/") for n in z.namelist())
    gecko = (man.get("browser_specific_settings")
             or man.get("applications") or {}).get("gecko", {})
    return {"name": name, "version": man.get("version"),
            "id": gecko.get("id"), "signed": signed}


def profile_in_use(profile):
    try:
        out = subprocess.run(["lsof", "+D", profile], capture_output=True,
                             text=True, timeout=60).stdout
        if sum(1 for ln in out.splitlines() if "irefox" in ln):
            return True
    except Exception:
        pass
    return subprocess.run(["pgrep", "-f", f"--profile {profile}"],
                          capture_output=True).returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("xpis", nargs="+")
    a = ap.parse_args()

    profile = os.path.expanduser(a.profile)
    if not os.path.isdir(profile):
        sys.exit(f"no such profile: {profile}")

    info = []
    for x in a.xpis:
        if not os.path.exists(x):
            sys.exit(f"missing xpi: {x}")
        d = describe(x)
        info.append((x, d))
        print(f"  {d['name']} {d['version']}")
        print(f"      id={d['id']}  signed={d['signed']}")
        if not d["signed"]:
            sys.exit("refusing to install an unsigned extension")

    if a.dry_run:
        print(f"\nwould install {len(info)} extension(s) into {profile}")
        return

    if profile_in_use(profile):
        sys.exit("that profile is open in Firefox — quit it first")

    # Back up the files that record addon state, so a bad install is undoable.
    stamp = time.strftime("%Y%m%d-%H%M%S")
    bk = os.path.join(os.path.expanduser("~/.local/share/firefox-minimal"),
                      f"addons-backup-{stamp}")
    os.makedirs(bk, exist_ok=True)
    for f in ("extensions.json", "prefs.js", "addonStartup.json.lz4"):
        src = os.path.join(profile, f)
        if os.path.exists(src):
            shutil.copy2(src, bk)
    print(f"\nbacked up addon state to {bk}")

    # Marionette's port comes from the `marionette.port` pref, NOT from an
    # environment variable — MOZ_MARIONETTE_PORT is ignored and the server
    # silently listens on the default 2828. Rather than edit the user's real
    # user.js, pass the pref for this run only via the command line.
    proc = subprocess.Popen(
        [FIREFOX, "--profile", profile, "--marionette",
         "-remote-allow-system-access", "--no-remote", "--new-instance",
         "--headless", "about:blank"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"firefox pid {proc.pid} (headless)")

    installed = []
    try:
        # Default port, since we are not overriding the pref.
        m = Marionette(port=2828, timeout=120)
        m.new_session()
        for path, d in info:
            try:
                r = m.send("Addon:Install", {"path": os.path.abspath(path),
                                             "temporary": False})
                got = r.get("value") if isinstance(r, dict) else r
                print(f"  installed: {d['name']} -> {got}")
                installed.append(d["id"])
            except Exception as e:
                print(f"  FAILED: {d['name']}: {e}")
            time.sleep(2)
        time.sleep(4)
        m.quit()
    finally:
        time.sleep(3)
        if proc.poll() is None:
            proc.terminate()
            time.sleep(3)
        if proc.poll() is None:
            proc.kill()

    print(f"\ninstalled {len(installed)}/{len(info)}")


if __name__ == "__main__":
    main()
