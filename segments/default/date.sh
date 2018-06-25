#!/bin/bash
#
# PowerStatus10k segment
# This segment displays the current date.
# The appearance depends on the format string that is used.
# The segment has a fixed icon.

# Implement the interface function to get the current state.
#
function getState_date {
  echo "${DATE_ICON} $(date +"$DATE_FORMAT")"
}
