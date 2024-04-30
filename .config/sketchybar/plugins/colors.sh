!/usr/bin/env bash

#
#
# Catppuccin Macchiato palette
#
#

export BASE=0xff24273a
export MANTLE=0xff1e2030
export CRUST=0xff181926

export TEXT=0xffcad3f5
export SUBTEXT0=0xffb8c0e0
export SUBTEXT1=0xffa5adcb

export SURFACE0=0xff363a4f
export SURFACE1=0xff494d64
export SURFACE2=0xff5b6078

export OVERLAY0=0xff6e738d
export OVERLAY1=0xff8087a2
export OVERLAY2=0xff939ab7

export BLUE=0xff8aadf4
export LAVENDER=0xffb7bdf8
export SAPPHIRE=0xff7dc4e4
export SKY=0xff91d7e3
export TEAL=0xff8bd5ca
export GREEN=0xffa6da95
export YELLOW=0xffeed49f
export PEACH=0xfff5a97f
export MAROON=0xffee99a0
export RED=0xffed8796
export MAUVE=0xffc6a0f6
export PINK=0xfff5bde6
export FLAMINGO=0xfff0c6c6
export ROSEWATER=0xfff4dbd6

export RANDOM_CAT_COLOR=("$BLUE" "$LAVENDER" "$SAPPHIRE" "$SKY" "$TEAL" "$GREEN" "$YELLOW" "$PEACH" "$MAROON" "$RED" "$MAUVE" "$PINK" "$FLAMINGO" "$ROSEWATER")

function getRandomCatColor() {
	echo "${RANDOM_CAT_COLOR[$RANDOM % ${#RANDOM_CAT_COLOR[@]}]}"
}

#
# LEGACY COLORS
#
# Color Palette
export GREY=0xff939ab7
export TRANSPARENT=0x00000000

# General bar colors
export BAR_COLOR=$BASE
export ICON_COLOR=$TEXT  # Color of all icons
export LABEL_COLOR=$TEXT # Color of all labels

export COLOR_BACKGROUND=0xe01d2021
export COLOR_FOREGROUND=0xe0fbf1c7

export COLOR_ACCENT=0xe0d65d0e
export COLOR_ACCENT_BRIGHT=0xe0fe8019

export COLOR_BLACK=0xe0282828
export COLOR_RED=0xe0cc241d
export COLOR_GREEN=0xe098971a
export COLOR_YELLOW=0xe0d79921
export COLOR_BLUE=0xe0458588
export COLOR_MAGENTA=0xe0b16286
export COLOR_CYAN=0xe0689d6a
export COLOR_WHITE=0xe0a89984

export COLOR_BLACK_BRIGHT=0xe0928374
export COLOR_RED_BRIGHT=0xe0fb4934
export COLOR_GREEN_BRIGHT=0xe0b8bb26
export COLOR_YELLOW_BRIGHT=0xe0fabd2f
export COLOR_BLUE_BRIGHT=0xe083a598
export COLOR_MAGENTA_BRIGHT=0xe0d3869b
export COLOR_CYAN_BRIGHT=0xe08ec07c
export COLOR_WHITE_BRIGHT=0xe0ebdbb2
