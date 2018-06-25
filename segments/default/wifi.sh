#!/bin/bash

# Icons
WIFI_ICON_CONNECTED="直"
WIFI_ICON_DISCONNECTED="睊"

# Interface name variable.
WIFI_INTERFACE_NAME="wlp4s0"

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
