#!/bin/sh

# Factory script to create popup items for a power widget
# Usage: power_popup_factory.sh <parent_item_name>

SKETCHYBAR=/opt/homebrew/bin/sketchybar
PARENT="$1"

if [ -z "$PARENT" ]; then
  exit 1
fi

# Add popup items for this parent
$SKETCHYBAR \
  --add item ${PARENT}_pp_header_power popup.${PARENT} \
  --set ${PARENT}_pp_header_power icon="󱐋" label="POWER" icon.color=0xff89b4fa label.color=0xff89b4fa \
  --add item ${PARENT}_pp_system popup.${PARENT} \
  --set ${PARENT}_pp_system icon="󱐋" label="System: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_cpu popup.${PARENT} \
  --set ${PARENT}_pp_cpu icon="󰍛" label="CPU: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_gpu popup.${PARENT} \
  --set ${PARENT}_pp_gpu icon="󰢮" label="GPU: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_ane popup.${PARENT} \
  --set ${PARENT}_pp_ane icon="󰧑" label="ANE: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_display popup.${PARENT} \
  --set ${PARENT}_pp_display icon="󰍹" label="Display: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_other popup.${PARENT} \
  --set ${PARENT}_pp_other icon="󰘚" label="Other: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_header_clusters popup.${PARENT} \
  --set ${PARENT}_pp_header_clusters icon="󰻠" label="CPU CLUSTERS" icon.color=0xffcba6f7 label.color=0xffcba6f7 \
  --add item ${PARENT}_pp_ecluster popup.${PARENT} \
  --set ${PARENT}_pp_ecluster icon="E" label="E-Cluster: --" icon.padding_left=12 \
  --add item ${PARENT}_pp_p0cluster popup.${PARENT} \
  --set ${PARENT}_pp_p0cluster icon="P0" label="P0-Cluster: --" icon.padding_left=12 \
  --add item ${PARENT}_pp_p1cluster popup.${PARENT} \
  --set ${PARENT}_pp_p1cluster icon="P1" label="P1-Cluster: --" icon.padding_left=12 \
  --add item ${PARENT}_pp_header_battery popup.${PARENT} \
  --set ${PARENT}_pp_header_battery icon="󰁹" label="BATTERY" icon.color=0xffa6e3a1 label.color=0xffa6e3a1 \
  --add item ${PARENT}_pp_charge popup.${PARENT} \
  --set ${PARENT}_pp_charge icon="󰁹" label="Charge: --%"  icon.padding_left=12 \
  --add item ${PARENT}_pp_flow popup.${PARENT} \
  --set ${PARENT}_pp_flow icon="󰂄" label="Flow: --W" icon.padding_left=12 \
  --add item ${PARENT}_pp_status popup.${PARENT} \
  --set ${PARENT}_pp_status icon="󰂃" label="Status: --" icon.padding_left=12 \
  --add item ${PARENT}_pp_time popup.${PARENT} \
  --set ${PARENT}_pp_time icon="󰔚" label="Time: --" icon.padding_left=12 drawing=off \
  --add item ${PARENT}_pp_header_adapter popup.${PARENT} \
  --set ${PARENT}_pp_header_adapter icon="󰚥" label="ADAPTER" icon.color=0xfff9e2af label.color=0xfff9e2af drawing=off \
  --add item ${PARENT}_pp_adapter popup.${PARENT} \
  --set ${PARENT}_pp_adapter icon="󰚥" label="Adapter: --W" drawing=off icon.padding_left=12 \
  --add item ${PARENT}_pp_delivery popup.${PARENT} \
  --set ${PARENT}_pp_delivery icon="󱐌" label="Delivery: --W" drawing=off icon.padding_left=12
