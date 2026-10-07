#!/bin/sh
#
# powermetrics wrapper -- emits one JSON sample of CPU/GPU/ANE power.
#
# powermetrics refuses to run as anyone but root, so the bar reaches it through
# a NOPASSWD sudoers rule pinned to this exact path and argument list.
#
# SECURITY -- why this file lives in /usr/local/libexec and not in dotfiles:
#
#   A NOPASSWD rule is only as safe as the thing it points at. If the target
#   script were writable by the invoking user, anyone running as that user
#   could rewrite its contents and execute arbitrary code as root. This file
#   must therefore be owned by root with mode 755 -- readable and runnable by
#   everyone, writable by no one but root.
#
#   The sudoers rule pins the full argument vector, so `-o <file>` can never be
#   injected. That matters: powermetrics -o writes its output to an arbitrary
#   path as root, which would otherwise be a file-clobbering primitive.
#
#   Consequently this script takes NO arguments and interpolates nothing into
#   the command. It is a constant.
#
# Install (see install-power-monitor.sh in the sketchybar config dir):
#   sudo install -o root -g wheel -m 755 power_monitor.sh \
#        /usr/local/libexec/sketchybar-power-monitor
#
# Output: a single JSON object. Fields are null when unavailable rather than
# absent, so consumers can rely on the shape.

set -eu

PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH

# One 200ms sample. powermetrics' default is 5000ms, which would stall the
# calling bar item for five seconds.
#
# cpu_power carries the combined CPU/GPU/ANE package figures on Apple silicon.
SAMPLE=$(powermetrics --samplers cpu_power -n 1 -i 200 --format plist 2>/dev/null) || exit 1
[ -n "$SAMPLE" ] || exit 1

# powermetrics emits NUL-separated plists; keep the first.
SAMPLE=$(printf '%s' "$SAMPLE" | tr -d '\000')

printf '%s' "$SAMPLE" | plutil -convert json -o - -- - 2>/dev/null
