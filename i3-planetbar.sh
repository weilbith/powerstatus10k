#!/bin/bash

# Load the default and user configurations.
source $(dirname $0)/default.conf # Default values for all necessary variables.
source $(dirname $0)/custom.conf # Load after default values to be able to overwrite them.

# Load the segments.
source $(dirname $0)/segments.sh


# Define deviated variables.
[[ "$BOTTOM" = true ]] && BAR_BOTTOM_ARG="-b"


# Prepare the fifo.
rm -f "${FIFO}" # Make sure to delete a possible old fifo.
mkfifo "${FIFO}" # Create the fifo.


# This function is responsible to spawn the background processes for updating the segments.
# It compose a bunch of values used for each segment, the update process have to be aware about.
# Manage the order of segments and their colors.
#
function initSegments {
  # Always remember the background from the last segement, cause it is necessary for the separator.
  # The most left segment of the right site has to predecessor, so use the bars default background.
  previous_segment_background=$DEFAULT_BACKGROUND

  # Iterate over all segments in the list.
  for (( i=0; i<${#SEGMENT_LIST[@]}; i++ )) ; do
    # Get the next segment name.
    local segmentName="${SEGMENT_LIST[i]}"

    # Switch between primary and secundary color based on the index.
    if [[ $(( $i % 2 )) -eq 0 ]] ; then
      current_segment_background=$SEGMENT_BACKGROUND_PRIMARY
      current_segment_foreground=$SEGMENT_FOREGROUND_PRIMARY
    
    else 
      current_segment_background=$SEGMENT_BACKGROUND_SECUNDARY
      current_segment_foreground=$SEGMENT_FOREGROUND_SECUNDARY
    fi

    # Open a background process, which updates this segment.
    updateSegment "${SEGMENT_UPDATE_INTERVAL_DEFAULT}s" "$segmentName" $i "right" "$current_segment_background" "$current_segment_foreground" "$previous_segment_background" &

    # Update previous segment background.
    previous_segment_background=$current_segment_background
  done
}


# Background process that call the segments function to get the current state.
# Based on the given arguments this function design the format string for the bar.
# This function is aware of the position of the segment.
# The updated format string will be written to the fifo, where it gets read and pass to the bar.
#
# Arguments:
#   $1 - The interval in which the segment should be updated
#   $2 - Name of the segment (used as reference)
#   $3 - Index in the sement order
#   $4 - Orientiation (left/right)
#   $5 - Background color of this segment
#   $6 - Foreground color of this segment
#   $7 - Background color of the previous segment (for the separator)
#
function updateSegment {
  # Start a endless loop for this process, responsible for this segment.
  while true ; do
    # Get the current state of the segment, by its reposible function.
    local state=$("getState_$2")

    # Get the separator by the orientation.
    local separator
    [[ "$4" = 'right' ]] && separator="$SEGMENT_SEPARATOR_RIGHT_OUTER" || separator="$SEGMENT_SEPARATOR_LEFT_OUTER"  

    # Compose the segment format string.
    local segment_format_string="%{B${7} F${5}}${separator}%{B${5} F${6}} ${state} %{F- B-}"

    # Pass the format string to the fifo. 
    printf "%s\n" "${3}${segment_format_string}" > "${FIFO}"

    # Wait for the defined period.
    sleep "$1"
  done
}


# Function which run in background and read from the fifo.
# Hold an array where each entry is the format string of one segment.
# An fifo entry is suffixed by the segment index, which is equal to the array index.
# Pass the concatenation of all segments format strings to the standard output.
#
function reading {
  # Array which holds the current format string for all segments.
  declare -A format_string_list=()

  # Define local variables.
  local index # Temporally store the index of the to update segement.
  local format_string # Hold the concatenation of all format strings.

  # Keep open endless loop as long as the process is running.
  while true ; do
    # Wait until fifo has content.
    if read line < /tmp/i3_planetbar ; then
      # Parse the first character as the index of the segment.
      index=${line:0:1}

      # Update the format string in the list of all segements.
      format_string_list[$index]="${line:1}"

      # Pass the current format string list to the bar.
      format_string=$(printf %s "${format_string_list[@]}" $'\n')
      echo "%{r}${format_string}"
    fi
  done
}


# Getting started
initSegments # Start all background processes, handling the segments.
reading | # Run process which read from the fifo and pass the whole format string to the bar.
$(dirname $0)/lemonbar -p -d "$BAR_BOTTOM_ARG" -f "$FONT_DEFAULT:size=$FONT_SIZE" -B "$DEFAULT_BACKGROUND" -F "$DEFAULT_FOREGROUND" -g "x$HEIGHT" & # Run lemonbar in background and read from the standard input.
wait # Wait here and do not end. 
