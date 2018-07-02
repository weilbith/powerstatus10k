#!/bin/bash

# Store the source and configuration directory, cause it is used several times.
BASE_DIR="$(dirname $0)"
CONFIG_DIR=$BASE_DIR/config

# Load the default and user configurations.
source $CONFIG_DIR/default.conf # Default values for all necessary variables.
source $CONFIG_DIR/custom.conf # Load after default values to be able to overwrite them.

# Script "Imports"
SCRIPT_SEPARATOR_BUILDER="$(dirname $0)/SeparatorBuilder.sh"


# Based on the given arguments this function design the format string for the bar.
# This function is aware of the position of the segment.
# The updated format string will be written to the fifo, where it gets read and pass to the bar.
#
# Arguments:
#   $1  - Name of the segment (used as reference)
#   $2  - Orientation [l|r|c]
#   $3  - Index in the segment order
#   $4  - Background color of this segment
#   $5  - Foreground color of this segment
#   $6  - Background color of the previous segment (for the separator)
#   $7  - Background color of the next segment (for the separator)
#   $8  - segment implementation path (relative)
#   $9  - segment confiuration path (relative)
#
function updateSegment {
  # Source the implementation and configuration of this segment.
  source $8

  if [[ ! -z "$9" ]] ; then
    source $9
    source $CONFIG_DIR/custom.conf # Load again to update segment specific custom variables.
  fi

  # Define the update interval by try to get a custom defined one or use defaul.
  local update_interval
  eval "local custom_update_interval=\$${1^^}_UPDATE_INTERVAL"

  if [[ ${custom_update_interval} -gt 0 ]] ; then
    # Use custom interval.
    update_interval=$custom_update_interval
  else
    # Use default interval.
    update_interval=${DEFAULT_UPDATE_INTERVAL}
  fi

  # Define static variables in use to update the segment.
  local left_separator_format_string="$($SCRIPT_SEPARATOR_BUILDER 'l' $2 $3 $4 $6 $7)"
  local right_separator_format_string="$($SCRIPT_SEPARATOR_BUILDER 'r' $2 $3 $4 $6 $7)"
  local state_color_before="%{B${4} F${5}}"
  local color_clear="%{F- B-}"
  local segment_format_string

  # Store the state to be aware of changes in the state.
  local lastState=""

  # Start a endless loop for this process, responsible for this segment.
  while true ; do
    # Get the current state of the segment, by its reposible function.
    local state=$("getState_$1")

    # Do nothing further, it the state has not changed.
    if [[ ! "$lastState" = "$state" ]] ; then
      # Store state for next update.
      lastState="$state"

      # Compose the segment format string.
      segment_format_string="${left_separator_format_string}${state_color_before} ${state} ${right_separator_format_string}${color_clear}"

      # Pass the format string to the fifo. 
      printf "%s\n" "${3}${2}${segment_format_string}" > "${FIFO}" &
    fi

    # Wait for the defined period.
    sleep "${update_interval}s"
  done
}


# Call the update segment function with all arguments.
updateSegment $@
