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
  essid=$(iwconfig ${WIFI_INTERFACE_NAME} | grep -o -P '(?<=ESSID:).*') 

  # Check if WIFI is disconnected.
  if [[ "$essid" = *off/any* ]] ; then
    icon="${WIFI_ICON_DISCONNECTED}"
    essid="off"
  fi

  # Remove quotation marks around the ESSID.
  essid=$(echo "${essid}" | sed 's/"//g')

  # Build the state string.
  echo "${icon} ${essid}"
}
