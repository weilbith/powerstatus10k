#!/bin/bash
#
# PowerStatus10k segment.
# Segment displays the current memory usage.

# Implement the interface function to get the current state.
#
function getState_memory {
  # Get the memory usage information string.
  infoString=$(free -h | grep Mem:)

  # Trim the mass of spaces and split the information segments to a list.
  infoString=$(echo "$infoString" | tr -s " ")
  IFS=' ' read -ra infoList <<< "$infoString"

  # Get the current usage and make it look better.
  usage=$(echo "${infoList[2]}" | sed 's/,/./' | sed 's/G/GB/' | sed 's/M/MB/')

  # Build the final status as format string.
  STATE="${MEMORY_ICON} ${usage}"
}
