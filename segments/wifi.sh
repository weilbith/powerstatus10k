#!/bin/bash
#
# PowerStatus10k segment.
# This segment displays the wifi status.
# Differs between connected and not to differ the icon.
# If connected, it shows the ESSID of the network.

# Implement the interface function to get the current state.
#
function getState_wifi {
  icon="${WIFI_ICON_CONNECTED}" # Use the connected icon per default.
  ssid=$(iw dev | grep -A5 "$WIFI_INTERFACE_NAME" | grep "ssid" | awk -F ' ' '{print $2}') 

  # Check if WIFI is disconnected.
  if [[ -z "$ssid" ]] ; then
    icon="${WIFI_ICON_DISCONNECTED}"
    ssid="off"
  fi

  essidAbbr=$(abbreviate "$ssid" "wifi")

  # Build the state string.
  STATE="${icon} ${essidAbbr}"
}
