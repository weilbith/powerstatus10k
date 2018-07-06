#!/bin/bash
#
# PowerStatus10k segment.
# This segment displays the time.
# The appearance depends on the format string that is used.
# The segment has a fixed icon.

# Implement the interface function to get the current state.
#
function getState_time {
  STATE="${TIME_ICON} $(date +"$TIME_FORMAT")"
}
