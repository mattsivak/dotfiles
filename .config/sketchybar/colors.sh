#!/bin/sh
#
# ayu dark palette, sourced by sketchybarrc and the plugins.
#
# Values are taken verbatim from the Shatur/neovim-ayu colorscheme this machine
# runs in Neovim (lua/ayu/colors.lua, dark variant with mirage = false), so the
# bar matches the editor exactly. Switching to the mirage variant means
# swapping this file's values, not hunting hex literals across the config.
#
# sketchybar colors are 0xAARRGGBB.

# --- Base -------------------------------------------------------------------
export AYU_BG=0xff0b0e14          # editor background
export AYU_LINE=0xff11151c        # current line / subtle raised surface
export AYU_PANEL_BG=0xff0f131a    # popup background
export AYU_PANEL_BORDER=0xff1e222a
export AYU_FG=0xffbfbdb6          # primary text
export AYU_UI=0xff565b66          # dimmed/idle text
export AYU_COMMENT=0xff636a72

# --- Accents ----------------------------------------------------------------
export AYU_ACCENT=0xffe6b450      # ayu's signature gold: focus/active
export AYU_TAG=0xff39bae6         # cyan
export AYU_ENTITY=0xff59c2ff      # blue
export AYU_STRING=0xffaad94c      # green
export AYU_FUNC=0xffffb454        # orange-yellow
export AYU_KEYWORD=0xffff8f40     # orange
export AYU_CONSTANT=0xffd2a6ff    # purple
export AYU_OPERATOR=0xfff29668    # salmon
export AYU_MARKUP=0xfff07178      # pink-red
export AYU_SPECIAL=0xffe6b673     # muted gold
export AYU_ERROR=0xffd95757
export AYU_WARNING=0xffff8f40

# --- Semantic aliases used by the bar ---------------------------------------
# BAR_COLOR is kept for reference only: the bar surface itself is transparent
# (0x00000000) since the split-pill layout, so nothing reads this. The visible
# background is ISLAND_BG below.
export BAR_COLOR=$AYU_BG
export ITEM_FG=$AYU_FG
export ITEM_ICON=$AYU_UI
export SPACE_ACTIVE_BG=0x33e6b450  # accent at 20% alpha behind the focused space
export SPACE_ACTIVE_FG=$AYU_ACCENT
export SPACE_IDLE_FG=$AYU_UI
export POPUP_BG=$AYU_PANEL_BG
export POPUP_BORDER=$AYU_PANEL_BORDER

# The bar itself is transparent; the visible surface is the two bracket
# "islands" that group the left and right items. These are their colors.
#
# Deliberately NOT $AYU_BG, even though the islands are meant to be ayu's
# background and both this bar and Ghostty are configured with #0b0e14.
#
# Ghostty colour-manages its output: terminal colours are converted into the
# display's colour space before drawing. On the built-in Display P3 panel,
# sRGB #0b0e14 converts and quantises to #0c0e13. sketchybar writes colours
# straight to the framebuffer with no conversion, so it painted #0b0e14 exactly
# -- and the two backgrounds sat one step apart in red and blue along the edge
# where a window meets the bar. Measured from a screenshot: deltaE 0.71, right
# at the just-noticeable threshold, and hard edges are where the eye is most
# sensitive to a seam.
#
# Correcting it here rather than in Ghostty's config is the better side of the
# fix: Ghostty's value is ayu's real background, shared with Neovim running
# inside it, so changing it would push the discrepancy into the editor. The bar
# is the only thing drawing uncorrected pixels, so the bar is what adapts.
#
# #0c0e13 is a fixed point of the sRGB->P3 conversion (it maps to itself), so
# this stays correct whether or not sketchybar's colours are ever colour-managed
# in a future release.
#
# Caveat: tuned for the P3 built-in display. On a plain sRGB external monitor
# Ghostty performs no conversion and renders #0b0e14, leaving the bar one step
# off in the other direction there -- invisible in practice, but the reason this
# is a separate variable rather than an edit to AYU_BG.
export ISLAND_BG=0xff0c0e13
export ISLAND_BORDER=$AYU_PANEL_BORDER
