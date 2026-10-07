# Sketchybar improvement plan

Derived from FelixKratz/SketchyBar discussion #47 ("Share your setups", 228
comments, read 2026-10-07) cross-referenced against this machine's config.

## Baseline measured on 2026-10-07

- sketchybar v2.24.0, 160 items, 12 space indicators, CPU 0.0%, RSS ~0.1%
- Config: POSIX-sh `sketchybarrc` + 11 plugins, derived from the stock example
- Fork+exec load from `update_freq` polling: **~50 per minute (~3030/hour)**
  | item | freq | forks/min |
  |---|---|---|
  | power_trigger | 2s | 30.0 |
  | memory | 5s | 12.0 |
  | clock | 10s | 6.0 |
  | ip_address | 30s | 2.0 |
  | battery | 120s | 0.5 |
- `power_trigger` (60% of all forks) calls `/usr/local/bin/mac_power_monitor`,
  which **does not exist on this machine**. It forks every 2s to do nothing.

## What the top setups actually use

Ranked by mention count across the thread:

| Mentions | Technique |
|---|---|
| 41 | `sketchybar-app-font` — per-app glyphs in space indicators |
| 34 | SbarLua — Lua config over mach messages, no fork/exec |
| 21 | menu bar aliases — render real macOS menu extras inside the bar |
| 20 | popup menus on hover/click |
| 20 | animations (`--animate sin 30`) |
| 15 | SF Symbols instead of Nerd Font glyphs |

Top-voted configs for reference:
- neutonfoo/dotfiles (72) — minimalist catppuccin, notch-aware
- FelixKratz/dotfiles (47) — now fully Lua; app icons in spaces, right-click
  destroys space, click separator creates one
- Pe8er/dotfiles (35) — tuned to look native
- shahmilav/dotfiles (26) — native-looking, SF Symbols, WiFi dropdown

## Plan, ordered by value/effort

### P0 — Fix what is actively broken or wasteful

1. **Resolve the power widgets.** Either build/obtain `mac_power_monitor`
   (JSON spec is in `mac_power_monitor.md`) or delete the 7 power items and
   `power*.sh`. This removes 30 forks/min and 136 of 160 items.
2. **Persist `external_bar` in `~/.yabairc`.** Line 46 references
   `$NORMAL_BAR`/`$NOTCH_UUID`, both commented out at lines 35-37, so on a
   yabai restart it evaluates to `all::0` and the inset is lost.
   Either define the variables or hardcode `all:38:0`.

### P1 — Cheap wins, high visible payoff

3. **App icons in space indicators** (`sketchybar-app-font`, 41 mentions).
   Shows which apps live on each space. Needs the font + a `space_windows`
   subscription. This is the single most-adopted upgrade in the thread.
4. **Drop polling for event subscriptions.** `clock` at 10s can be 60s;
   `memory` at 5s is far more often than anyone reads it. `volume` and
   `front_app` are already event-driven and cost nothing — follow that model.
5. **Animations** — `sketchybar --animate sin 30` on space switches and
   front_app changes. Pure cosmetics, ~2 lines.

### P2 — Structural

6. **Consider SbarLua** if the config grows. Felix's own config moved to it;
   communication is mach-message only, cutting the fork->exec->mach overhead
   entirely. Cost: a full rewrite of rc + plugins.
7. **Menu bar aliases** (21 mentions) — render real menu extras (e.g. battery,
   wifi, third-party status items) inside sketchybar, so the native bar can
   stay hidden permanently.

### P3 — Polish

8. Theme coherence — pick one palette (catppuccin/gruvbox/nord are the
   thread's favourites) and extract a `colors.sh`, rather than the hex
   literals currently scattered through `sketchybarrc`.
9. Notch awareness — this machine has a notched display plus two externals;
   several setups split left/right item groups around the notch.
