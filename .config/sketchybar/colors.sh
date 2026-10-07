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
export ISLAND_BG=$AYU_BG
export ISLAND_BORDER=$AYU_PANEL_BORDER
