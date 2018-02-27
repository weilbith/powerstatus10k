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
  local next_segment_background

  # Initialize the left segments.
  for (( i=0; i<${#SEGMENT_LIST_LEFT[@]}; i++ )) ; do
    # Get the next segment name.
    local segmentName="${SEGMENT_LIST_LEFT[i]}"

    # Switch between primary and secundary color based on the index.
    if [[ $(( $i % 2 )) -eq 0 ]] ; then
      current_segment_background=$SEGMENT_BACKGROUND_PRIMARY
      current_segment_foreground=$SEGMENT_FOREGROUND_PRIMARY
      next_segment_background=$SEGMENT_BACKGROUND_SECUNDARY

    else 
      current_segment_background=$SEGMENT_BACKGROUND_SECUNDARY
      current_segment_foreground=$SEGMENT_FOREGROUND_SECUNDARY
      next_segment_background=$SEGMENT_BACKGROUND_PRIMARY
    fi

    
    # Reset next segment background for last left segment.
    if [[ "$i" = "$((${#SEGMENT_LIST_LEFT[@]}-1))" ]] ; then
      next_segment_background=$DEFAULT_BACKGROUND
    fi


    # Open a background process, which updates this segment.
    updateSegment "${SEGMENT_UPDATE_INTERVAL_DEFAULT}s" "$segmentName" $i "l" "$current_segment_background" "$current_segment_foreground" "$next_segment_background" &

    # Update previous segment background.
    previous_segment_background=$current_segment_background
  done


  # Initialize the right segments.
  previous_segment_background=$DEFAULT_BACKGROUND

  for (( i=0; i<${#SEGMENT_LIST_RIGHT[@]}; i++ )) ; do
    # Get the next segment name.
    local segmentName="${SEGMENT_LIST_RIGHT[i]}"

    # Switch between primary and secundary color based on the index.
    if [[ $(( $i % 2 )) -eq 0 ]] ; then
      current_segment_background=$SEGMENT_BACKGROUND_PRIMARY
      current_segment_foreground=$SEGMENT_FOREGROUND_PRIMARY
    
    else 
      current_segment_background=$SEGMENT_BACKGROUND_SECUNDARY
      current_segment_foreground=$SEGMENT_FOREGROUND_SECUNDARY
    fi

    # Open a background process, which updates this segment.
    updateSegment "${SEGMENT_UPDATE_INTERVAL_DEFAULT}s" "$segmentName" $i "r" "$current_segment_background" "$current_segment_foreground" "$previous_segment_background" &

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
#   $4 - Orientiation [l,r]
#   $5 - Background color of this segment
#   $6 - Foreground color of this segment
#   $7 - Background color of the next/previous segment (for the separator)(depending on orientation)
#
function updateSegment {
  # Define persistent properties.
  # Get the separator by the orientation.
  local separator_char
  [[ "$4" = 'l' ]] && separator_char="$SEGMENT_SEPARATOR_LEFT_OUTER" || separator_char="$SEGMENT_SEPARATOR_RIGHT_OUTER"  

  local separator_format_string="%{B${7} F${5}}${separator_char}"
  local state_color_before="%{B${5} F${6}}"
  local color_clear="%{F- B-}"
  local segment_format_string=

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

      # Compose the segment format string depending on the orientation.
      if [[ "$4" = 'l' ]] ; then
        segment_format_string="${state_color_before} ${state} ${separator_format_string}${color_clear}"
      
      else 
        segment_format_string="${separator_format_string}${state_color_before} ${state} ${color_clear}"
      fi

      # Pass the format string to the fifo. 
      printf "%s\n" "${4}${3}${segment_format_string}" > "${FIFO}" &
    fi

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
  # Arrays which holds the current format string for the left and right segments.
  declare -A format_string_list_left=()
  declare -A format_string_list_right=()

  # Define local variables.
  local orientation # Decide in which list the segment belong to.
  local index # Temporally store the index of the to update segement.
  local format_string_left # Hold the concatenation of all left segments.
  local format_string_right # Hold the concatenation of all right segments.
  local format_string # Hold the concatenation of all format strings.

  # Keep open endless loop as long as the process is running.
  while true ; do
    # Wait until fifo has content.
    if read line ; then
      # Parse the first and second character as the orientation and the index of the segment.
      orientation=${line:0:1}
      index=${line:1:1}

      # Update the format string in the reponsive list.
      if [[ "$orientation" = 'l' ]] ; then
        format_string_list_left[$index]="${line:2}"

      else 
        format_string_list_right[$index]="${line:2}"
      fi

      # Pass the current format string list to the bar.
      format_string_left=$(printf %s "${format_string_list_left[@]}" $'\n')
      format_string_right=$(printf %s "${format_string_list_right[@]}" $'\n')
      format_string="%{l}${format_string_left}%{r}${format_string_right}"
      echo ${format_string}
    fi

    # Sleep minimum of time, after which a new update is possible.
    # In case that the fifo directly contains a new update, it would be ignored by the lemonbar, if no short delay is inserted.
    sleep 0.03s
  done < "$FIFO"
}


# Getting started
initSegments # Start all background processes, handling the segments.
reading | # Run process which read from the fifo and pass the whole format string to the bar.
$(dirname $0)/lemonbar -p -d "$BAR_BOTTOM_ARG" -f "$FONT_DEFAULT:size=$FONT_SIZE" -B "$DEFAULT_BACKGROUND" -F "$DEFAULT_FOREGROUND" -g "x$HEIGHT" & # Run lemonbar in background and read from the standard input.
wait # Wait here and do not end. 
