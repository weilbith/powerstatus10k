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
# Source the default update interval and FIFO name from the configurations.
source <(cat $CONFIG_DIR/default.conf | grep -E "^DEFAULT_UPDATE_INTERVAL|^FIFO|^ABBREVIATION_ENABLED")

# Source the implementation and configuration of this segment.
source $8

# Source the segments own default configuration.
if [[ ! -z "$9" ]] ; then
  source $9
fi

# Source the custom configuration for this segment.
source <(cat $CONFIG_DIR/custom.conf | grep -i -E "^$1|^COLOR|^ABBREVIATION")

# Source the abbreviation utils.
eval "abbreviationAvailable=\$${NAME^^}_ABBREVIATION_AVAILABLE"

# Check if this segment has abbreviations available.
if [[ "$abbreviationAvailable" = 'true' ]] ; then
  echo "Abbreviation is enabled for $NAME" >> test.log
  # Check if the user has explicitly enabled abbreviations for this segment.
  eval "abbreviationEnabled=\$${NAME^^}_ABBREVIATION_ENABLED"

  echo "Excplitely: $abbreviationEnabled" >> test.log

  # If not, check the default abbreviation enable which at least set by the default configuration.
  if [[ -z "$abbreviationEnabled" ]] ; then
    echo "Load default config" >> test.log
    abbreviationEnabled=$ABBREVIATION_ENABLED
    echo "Result: $abbreviationEnabled" >> test.log
  fi

  # Source the abbreviation utilities for this segment.
  if [[ "$abbreviationEnabled" = 'true' ]] ; then
    echo "Load utils" >> test.log
    source $BASE_DIR/AbbreviationUtils.sh

  # Provide a dummy function, so the segment doesn't fail on try to abbreviate.
  else
    function abbreviate {
      echo "$1"
    }
  fi
fi



# Define static variables in use to update the segment.
LEFT_SEPARATOR_FORMAT_STRING="$($SCRIPT_SEPARATOR_BUILDER 'l' $2 $3 $4 $6 $7)"
RIGHT_SEPARATOR_FORMAT_STRING="$($SCRIPT_SEPARATOR_BUILDER 'r' $2 $3 $4 $6 $7)"
STATE_COLOR_BEFORE="%{B${4} F${5}}"
COLOR_CLEAR="%{F- B-}"

# Build the format string by the given current state
# and a bunch of pre-calculated values.
# The format string gets forwarded to the FIFO.
#
# Arguments:
#   $1 - current state as content of the segment
#
function buildAndForward {
  # Add the control parts.
  formatString="${INDEX}${ORIENTATION}"

  # Add separators and content.
  formatString="${formatString}${LEFT_SEPARATOR_FORMAT_STRING}${STATE_COLOR_BEFORE} ${1} ${RIGHT_SEPARATOR_FORMAT_STRING}${COLOR_CLEAR}"

  # Pass the format string to the FIFO. 
  printf "%s\n" "${formatString}" > "${FIFO}" &
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
