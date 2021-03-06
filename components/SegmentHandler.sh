#!/bin/bash
# shellcheck disable=SC1090,SC2002
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

# Save some arguments globally.
NAME=$1
ORIENTATION=$2
INDEX=$3


# Sourcing
# Source the default update interval and FIFO name from the configurations.
source <(cat "$POWERSTATUS10K_FILE_CONFIG_GLOBAL" | grep -E "^DEFAULT_UPDATE_INTERVAL|^FIFO|^ABBREVIATION")

# Source the implementation of this segment.
source "$8"

# Source the segments own default configuration.
if [[ ! -z "$9" ]] ; then
  source "$9"
fi

# Source the custom configuration for this segment.
[[ -f "$POWERSTATUS10K_FILE_CONFIG_USER" ]] && \
  source <(cat "$POWERSTATUS10K_FILE_CONFIG_USER" | grep -i -E "^$NAME|^COLOR|^ABBREVIATION")

# Source the abbreviation utils.
declare abbreviationAvailable
eval "abbreviationAvailable=\$${NAME^^}_ABBREVIATION_AVAILABLE"

# Check if this segment has abbreviations available.
if [[ "$abbreviationAvailable" = 'true' ]] ; then
  # Check if the user has explicitly enabled abbreviations for this segment.
  eval "abbreviationEnabled=\$${NAME^^}_ABBREVIATION_ENABLED"

  # If not, check the default abbreviation enable which at least set by the default configuration.
  if [[ -z "$abbreviationEnabled" ]] ; then
    abbreviationEnabled=$ABBREVIATION_ENABLED
  fi

  # Source the abbreviation utilities for this segment.
  if [[ "$abbreviationEnabled" = 'true' ]] ; then
    source "$POWERSTATUS10K_COMPONENT_UTILS_ABBREVIATION"

  # Provide a dummy function, so the segment doesn't fail on try to abbreviate.
  else
    function abbreviate {
      echo "$NAME"
    }
  fi
fi



# Define static variables in use to update the segment.
LEFT_SEPARATOR_FORMAT_STRING="$("$POWERSTATUS10K_COMPONENT_SEPARATOR_BUILDER" 'l' "$2" "$3" "$4" "$6" "$7")"
RIGHT_SEPARATOR_FORMAT_STRING="$("$POWERSTATUS10K_COMPONENT_SEPARATOR_BUILDER" 'r' "$2" "$3" "$4" "$6" "$7")"
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
  printf "%s\\n" "${formatString}" > "${POWERSTATUS10K_FILE_FIFO_MAIN}" &
}

# Function that will handle a subscribing segments process.
# Create the FIFO for this subscription.
# Show the initial state of the segment.
#
function handleSubscribtionSegment {
  # Open a new FIFO for this segment.
  segmentFifo="${POWERSTATUS10K_DIR_FIFOS}/${NAME}"
  rm -f "${segmentFifo}" # Make sure to delete a possible old FIFO.
  mkfifo "${segmentFifo}" # Create the FIFO.

  # Get the initial content of the segment and display it.
  { "initState_$NAME"; }
  buildAndForward "$STATE"

  while true ; do
    # Wait until FIFO has content.
    content="$(cat "$segmentFifo")"
    readarray -t lines <<<"$content"

    # Parse each entry of the read FIFO content.
    for (( i=0; i<${#lines[@]}; i++ )) ; do
      line="${lines[i]}"

      # Let the segment implementation build the format string.
      { "format_$NAME" "$line"; }

      buildAndForward "$STATE"
    done
  done
}

# Function that will handle a cycle based segments process.
# Determines the update interval of this segment.
# Only cause an update of the segments content if the state has changed.
#
function handleCycleSegment {
  # Define the update interval by try to get a custom defined one or use default.
  local custom_update_interval
  eval "custom_update_interval=\$${NAME^^}_UPDATE_INTERVAL"

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
    { "getState_$NAME"; }

    # Do nothing further, it the state has not changed.
    if [[ ! "$lastState" = "$STATE" ]] ; then
      # Store state for next update.
      lastState="$STATE"

      buildAndForward "$STATE"
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
