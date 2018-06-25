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
#   $1 - The interval in which the segment should be updated
#   $2 - Name of the segment (used as reference)
#   $3 - Orientation [l|r|c]
#   $4 - Index in the segment order
#   $5 - Background color of this segment
#   $6 - Foreground color of this segment
#   $7 - Background color of the previous segment (for the separator)
#   $8 - Background color of the next segment (for the separator)
#   $9 - segment implementation path (relative)
#
function updateSegment {
  # Source the implementation of this segment and update configuration.
  source $9
  source $CONFIG_DIR/custom.conf # Load again to update segment specific custom variables.

  # Define static variables in use to update the segment.
  local left_separator_format_string="$($SCRIPT_SEPARATOR_BUILDER 'l' $3 $4 $5 $7 $8)"
  local right_separator_format_string="$($SCRIPT_SEPARATOR_BUILDER 'r' $3 $4 $5 $7 $8)"
  local state_color_before="%{B${5} F${6}}"
  local color_clear="%{F- B-}"
  local segment_format_string

  # Store the state to be aware of changes in the state.
  local lastState=""

  # Start a endless loop for this process, responsible for this segment.
  while true ; do
    # Get the current state of the segment, by its reposible function.
    local state=$("getState_$2")

    # Do nothing further, it the state has not changed.
    if [[ ! "$lastState" = "$state" ]] ; then
      # Store state for next update.
      lastState="$state"

      # Compose the segment format string.
      segment_format_string="${left_separator_format_string}${state_color_before} ${state} ${right_separator_format_string}${color_clear}"

      # Pass the format string to the fifo. 
      printf "%s\n" "${4}${3}${segment_format_string}" > "${FIFO}" &
    fi

    # Wait for the defined period.
    sleep "$1"
  done
}


# Call the update segment function with all arguments.
updateSegment $@
