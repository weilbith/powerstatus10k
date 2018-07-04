#!/bin/bash
#
# Based on the given arguments this script designs the format string for the bar.
# This script is aware of the position of the segment.
# The updated format string will be written to the FIFO, where it gets read and pass to the bar.
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

# Store the source and configuration directory, cause it is used several times.
BASE_DIR="$(dirname $0)"
CONFIG_DIR=$BASE_DIR/config

# Script "Imports"
SCRIPT_SEPARATOR_BUILDER="$(dirname $0)/SeparatorBuilder.sh"

# Save some arguments globally.
NAME=$1
ORIENTATION=$2
INDEX=$3


# Sourcing
# Source the default update interval and FIFO name from the cofigurations.
source <(cat $CONFIG_DIR/default.conf | grep -E "^DEFAULT_UPDATE_INTERVAL|^FIFO")

# Source the implementation and configuration of this segment.
source $8

# Source the segments own default configuration.
if [[ ! -z "$9" ]] ; then
  source $9
fi

# Source the custom configuration for this segment.
echo "$NAME" >> test.log
source <(cat $CONFIG_DIR/custom.conf | grep -i -E "^$1|^COLOR")

# Define static variables in use to update the segment.
left_separator_format_string="$($SCRIPT_SEPARATOR_BUILDER 'l' $2 $3 $4 $6 $7)"
right_separator_format_string="$($SCRIPT_SEPARATOR_BUILDER 'r' $2 $3 $4 $6 $7)"
state_color_before="%{B${4} F${5}}"
color_clear="%{F- B-}"
segment_format_string=""

# Build the format string by the given current state
# and a bunch of pre-calculated values.
# The format string gets forwarded to the FIFO.
#
# Arguments:
#   $1 - current state as content of the segment
#
function buildAndForward {
  # Compose the segment format string.
  segment_format_string="${left_separator_format_string}${state_color_before} ${1} ${right_separator_format_string}${color_clear}"

  # Pass the format string to the FIFO. 
  printf "%s\n" "${INDEX}${ORIENTATION}${segment_format_string}" > "${FIFO}" &
}

# Function that will handle a subscribing segments process.
# Create the FIFO for this subscription.
# Show the initial state of the segment.
#
function handleSubscribtionSegment {
  # Open a new FIFO for this segment.
  segmentFifo="$FIFO_SEGMENT$NAME"
  rm -f "${segmentFifo}" # Make sure to delete a possible old FIFO.
  mkfifo "${segmentFifo}" # Create the FIFO.

  # Get the initial content of the segment and display it.
  state=$("initState_$NAME")
  buildAndForward "$state"

  while true ; do
    # Wait until FIFO has content.
    state="$(cat "$segmentFifo")"

    # Let the segment implementation build the format string.
    formatString=$("format_$NAME" "$state")

    buildAndForward "$formatString"
  done
}

# Function that will handle a cycle based segments process.
# Determines the update interval of this segment.
# Only cause an update of the segments content if the state has changed.
#
function handleCycleSegment {
  # Define the update interval by try to get a custom defined one or use defaul.
  eval "custom_update_interval=\$${1^^}_UPDATE_INTERVAL"

  if [[ ${custom_update_interval} -gt 0 ]] ; then
    # Use custom interval.
    update_interval=$custom_update_interval
  else
    # Use default interval.
    update_interval=${DEFAULT_UPDATE_INTERVAL}
  fi


  # Store the state to be aware of changes in the state.
  lastState=""

  # Start a endless loop for this process, responsible for this segment.
  while true ; do
    # Get the current state of the segment, by its reposible function.
    state=$("getState_$NAME")

    # Do nothing further, it the state has not changed.
    if [[ ! "$lastState" = "$state" ]] ; then
      # Store state for next update.
      lastState="$state"

      buildAndForward "$state"
    fi

    # Wait for the defined period.
    sleep "${update_interval}s"
  done
}


# Check if this is an subscribing segment or a cycle based one.
eval "subscribing=\$${1^^}_SUBSCRIBE"

[[ -z "$subscribing" ]] && subscribing=false

# Call the process handlers depending on the type.
if [[ "$subscribing" = 'true' ]] ; then
  handleSubscribtionSegment
else
  handleCycleSegment
fi
