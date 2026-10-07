#!/usr/bin/env python3
"""
Convert a Chromium-family `Bookmarks` JSON file (Helium, Chrome, Edge, Brave,
Vivaldi) into Netscape bookmark HTML, which is what Firefox imports.

    python3 chromium_bookmarks_to_html.py <Bookmarks> [-o out.html]

Pure stdlib, read-only on the source. Prints a tree summary to stderr so the
result can be eyeballed before importing.
"""
import argparse
import html
import json
import sys
from datetime import datetime, timezone

# Chromium timestamps are microseconds since 1601-01-01 (the Windows epoch);
# Netscape HTML wants seconds since the Unix epoch. 11644473600 is the gap.
WEBKIT_EPOCH_OFFSET = 11_644_473_600


def to_unix(chromium_ts):
    try:
        v = int(chromium_ts)
    except (TypeError, ValueError):
        return int(datetime.now(timezone.utc).timestamp())
    if v <= 0:
        return int(datetime.now(timezone.utc).timestamp())
    return max(0, v // 1_000_000 - WEBKIT_EPOCH_OFFSET)


def esc(s):
    return html.escape(s or "", quote=True)


def render(node, depth, out, counts):
    pad = " " * (4 * depth)
    for child in node.get("children", []):
        t = child.get("type")
        name = child.get("name", "")
        if t == "url":
            url = child.get("url", "")
            # javascript: and data: bookmarklets are executable; refuse to
            # carry them across silently.
            scheme = url.split(":", 1)[0].lower() if ":" in url else ""
            if scheme in ("javascript", "data"):
                counts["skipped"].append(f"{name} ({scheme}:)")
                continue
            add = to_unix(child.get("date_added"))
            out.append(
                f'{pad}<DT><A HREF="{esc(url)}" ADD_DATE="{add}">{esc(name)}</A>'
            )
            counts["urls"] += 1
        elif t == "folder":
            add = to_unix(child.get("date_added"))
            mod = to_unix(child.get("date_modified"))
            out.append(
                f'{pad}<DT><H3 ADD_DATE="{add}" LAST_MODIFIED="{mod}">'
                f"{esc(name)}</H3>"
            )
            out.append(f"{pad}<DL><p>")
            counts["folders"] += 1
            render(child, depth + 1, out, counts)
            out.append(f"{pad}</DL><p>")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("-o", "--output", default="-")
    ap.add_argument("--folder", default="Helium",
                    help="name for the wrapper folder when --wrap is used")
    ap.add_argument("--wrap", action="store_true",
                    help="nest everything under one folder instead of merging "
                         "the bookmark bar into Firefox's Bookmarks Toolbar")
    a = ap.parse_args()

    with open(a.source, encoding="utf-8") as f:
        data = json.load(f)

    counts = {"urls": 0, "folders": 0, "skipped": []}
    body = []

    roots = data.get("roots", {})
    # bookmark_bar first: it is the one users actually look at.
    order = ["bookmark_bar", "other", "synced"]
    labels = {"bookmark_bar": "Bookmarks bar",
              "other": "Other bookmarks",
              "synced": "Mobile bookmarks"}

    for key in order:
        root = roots.get(key)
        if not isinstance(root, dict):
            continue
        if not root.get("children"):
            continue

        if key == "bookmark_bar" and not a.wrap:
            # PERSONAL_TOOLBAR_FOLDER="true" is the marker Firefox's importer
            # looks for to merge a folder into the Bookmarks Toolbar rather
            # than filing it under "Other Bookmarks". Without it the folders
            # land somewhere the toolbar never shows.
            body.append('    <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">'
                        "Bookmarks Toolbar</H3>")
            body.append("    <DL><p>")
            render(root, 2, body, counts)
            body.append("    </DL><p>")
        else:
            body.append(f'    <DT><H3>{esc(labels.get(key, key))}</H3>')
            body.append("    <DL><p>")
            render(root, 2, body, counts)
            body.append("    </DL><p>")

    if a.wrap:
        body = [f"    <DT><H3>{esc(a.folder)}</H3>", "    <DL><p>",
                *["    " + b for b in body], "    </DL><p>"]

    # Firefox's importer treats the OUTERMOST <DL> as the bookmarks-menu root
    # and only merges a folder into the real toolbar when
    # PERSONAL_TOOLBAR_FOLDER sits on a DIRECT child of that list. Nesting it
    # one level deeper (inside a wrapper folder) produces an ordinary folder
    # that happens to be *named* "Bookmarks Toolbar", filed under the menu —
    # measured: 0 items on toolbar_____, the tree under menu________ instead.
    doc = [
        "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
        "<!-- This is an automatically generated file.",
        "     It will be read and overwritten.",
        "     DO NOT EDIT! -->",
        '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
        "<TITLE>Bookmarks</TITLE>",
        "<H1>Bookmarks</H1>",
        "<DL><p>",
        *body,
        "</DL><p>",
    ]
    text = "\n".join(doc) + "\n"

    if a.output == "-":
        sys.stdout.write(text)
    else:
        with open(a.output, "w", encoding="utf-8") as f:
            f.write(text)
        print(f"wrote {a.output}", file=sys.stderr)

    print(f"{counts['urls']} bookmarks in {counts['folders']} folders",
          file=sys.stderr)
    if counts["skipped"]:
        print(f"SKIPPED {len(counts['skipped'])} executable bookmarklet(s):",
              file=sys.stderr)
        for s in counts["skipped"]:
            print(f"  {s}", file=sys.stderr)


if __name__ == "__main__":
    main()
